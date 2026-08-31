import re
from sqlalchemy import desc, func
from app.config import FRONT_URL
from app.errors import NotFoundRequest
from app.models import Household, RecipeItems, RecipeTags
from flask import jsonify, Blueprint, request
from flask_jwt_extended import current_user, jwt_required
from app import db
from app.helpers import validate_args, authorize_household
from app.models import Recipe, Item, Tag
from app.models.recipe import RecipeVisibility
from app.service.file_has_access_or_download import file_has_access_or_download
from app.service.recipe_scraping import scrape
from app.service.recipe_pdf_import import extractPdfText, extractRecipeFromText
from app.service import pricing
from .schemas import (
    SearchByNameRequest,
    AddRecipe,
    SearchByTagRequest,
    UpdateRecipe,
    GetAllFilterRequest,
    ScrapeRecipe,
    ScrapeRecipeText,
    SuggestionsRecipe,
    GetRecipeCost,
)

recipe = Blueprint("recipe", __name__)
recipeHousehold = Blueprint("recipe", __name__)


@recipeHousehold.route("", methods=["GET"])
@jwt_required()
@authorize_household()
def getAllRecipes(household_id):
    return jsonify(
        [e.obj_to_full_dict() for e in Recipe.all_from_household_by_name(household_id)]
    )


@recipeHousehold.route("/newest/<int:page>", methods=["GET"])
@jwt_required()
def getNewesetPublicRecipesOfHousehold(household_id, page):
    return jsonify(
        [
            e.obj_to_public_dict()
            for e in Recipe.query.join(Recipe.household)
            .filter(
                Recipe.household_id == household_id,
                Recipe.visibility == RecipeVisibility.PUBLIC,
            )
            .order_by(desc(Recipe.id))
            .offset(page * 10)
            .limit(10)
            .all()
        ]
    )


@recipe.route("/<int:id>", methods=["GET"])
@jwt_required(optional=True)
def getRecipeById(id):
    recipe = Recipe.find_by_id(id)
    if not recipe:
        raise NotFoundRequest()
    if recipe.visibility == RecipeVisibility.PRIVATE:
        recipe.checkAuthorized()
        return jsonify(recipe.obj_to_full_dict())

    if recipe.isAuthorized():
        return jsonify(recipe.obj_to_full_dict())

    return jsonify(recipe.obj_to_public_dict())


@recipe.route("/<int:id>/cost", methods=["GET"])
@jwt_required()
@validate_args(GetRecipeCost)
def getRecipeCost(args, id):
    recipe = Recipe.find_by_id(id)
    if not recipe:
        raise NotFoundRequest()
    recipe.checkAuthorized()

    household = Household.find_by_id(recipe.household_id)
    if (
        not household
        or not household.pricing_feature
        or not household.preferred_store_id
    ):
        return jsonify(
            {"total": None, "complete": False, "priced_items": 0, "total_items": 0}
        )

    yield_factor = (
        args["yields"] / recipe.yields
        if "yields" in args and recipe.yields
        else 1.0
    )
    return jsonify(
        pricing.compute_recipe_cost(
            recipe, household.preferred_store_id, yield_factor
        )
    )


@recipeHousehold.route("", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(AddRecipe)
def addRecipe(args, household_id):
    recipe = Recipe()
    recipe.name = args["name"].strip()[:128]
    recipe.description = args["description"]
    recipe.household_id = household_id
    if "time" in args:
        recipe.time = args["time"]
    if "cook_time" in args:
        recipe.cook_time = args["cook_time"]
    if "prep_time" in args:
        recipe.prep_time = args["prep_time"]
    if "yields" in args:
        recipe.yields = args["yields"]
    if "source" in args:
        recipe.source = args["source"]
        localMatch = re.match(
            r"(kitchenowl:\/\/|"
            + re.escape((FRONT_URL or "").removesuffix("/"))
            + r")\/recipe\/(\d+)",
            recipe.source,
        )
        if localMatch:
            # Local recipe
            sourceRecipe = Recipe.find_by_id(int(localMatch.group(2)))
            if sourceRecipe:
                sourceRecipe.server_scrapes = sourceRecipe.server_scrapes + 1
                sourceRecipe.save()
    if "visibility" in args:
        recipe.visibility = RecipeVisibility(args["visibility"])
    if "photo" in args and args["photo"] != recipe.photo:
        recipe.photo = file_has_access_or_download(args["photo"], recipe.photo)
    if "server_curated" in args and current_user.admin:
        recipe.server_curated = args["server_curated"]
    recipe.save()
    if "items" in args:
        for recipeItem in args["items"]:
            item = Item.find_by_name(household_id, recipeItem["name"])
            if not item:
                item = Item.create_by_name(household_id, recipeItem["name"])
            con = RecipeItems(
                description=recipeItem["description"],
                optional=recipeItem["optional"],
                amount=recipeItem.get("amount"),
                unit=recipeItem.get("unit"),
            )
            con.item = item
            con.recipe = recipe
            con.save()
    if "tags" in args:
        for tagName in args["tags"]:
            tag = Tag.find_by_name(household_id, tagName)
            if not tag:
                tag = Tag.create_by_name(household_id, tagName)
            con = RecipeTags()
            con.tag = tag
            con.recipe = recipe
            con.save()
    return jsonify(recipe.obj_to_full_dict())


@recipe.route("/<int:id>", methods=["POST"])
@jwt_required()
@validate_args(UpdateRecipe)
def updateRecipe(args, id):  # noqa: C901
    recipe = Recipe.find_by_id(id)
    if not recipe:
        raise NotFoundRequest()
    recipe.checkAuthorized()

    if "name" in args:
        recipe.name = args["name"].strip()[:128]
    if "description" in args:
        recipe.description = args["description"]
    if "time" in args:
        recipe.time = args["time"]
    if "cook_time" in args:
        recipe.cook_time = args["cook_time"]
    if "prep_time" in args:
        recipe.prep_time = args["prep_time"]
    if "yields" in args:
        recipe.yields = args["yields"]
    if "source" in args:
        recipe.source = args["source"]
    if "visibility" in args:
        recipe.visibility = RecipeVisibility(args["visibility"])
    if "photo" in args and args["photo"] != recipe.photo:
        recipe.photo = file_has_access_or_download(args["photo"], recipe.photo)
    if "server_curated" in args and current_user.admin:
        recipe.server_curated = args["server_curated"]
    recipe.save()
    if "items" in args:
        for con in recipe.items:
            item_names = [e["name"] for e in args["items"]]
            if con.item.name not in item_names:
                con.delete()
        for recipeItem in args["items"]:
            item = Item.find_by_name(recipe.household_id, recipeItem["name"])
            if not item:
                item = Item.create_by_name(recipe.household_id, recipeItem["name"])
            con = RecipeItems.find_by_ids(recipe.id, item.id)
            if con:
                if "description" in recipeItem:
                    con.description = recipeItem["description"]
                if "optional" in recipeItem:
                    con.optional = recipeItem["optional"]
                if "amount" in recipeItem:
                    con.amount = recipeItem["amount"]
                if "unit" in recipeItem:
                    con.unit = recipeItem["unit"]
            else:
                con = RecipeItems(
                    description=recipeItem["description"],
                    optional=recipeItem["optional"],
                    amount=recipeItem.get("amount"),
                    unit=recipeItem.get("unit"),
                )
            con.item = item
            con.recipe = recipe
            con.save()
    if "tags" in args:
        for con in recipe.tags:
            if con.tag.name not in args["tags"]:
                con.delete()
        for recipeTag in args["tags"]:
            tag = Tag.find_by_name(recipe.household_id, recipeTag)
            if not tag:
                tag = Tag.create_by_name(recipe.household_id, recipeTag)
            con = RecipeTags.find_by_ids(recipe.id, tag.id)
            if not con:
                con = RecipeTags()
                con.tag = tag
                con.recipe = recipe
                con.save()
    return jsonify(recipe.obj_to_full_dict())


@recipe.route("/<int:id>", methods=["DELETE"])
@jwt_required()
def deleteRecipeById(id):
    recipe = Recipe.find_by_id(id)
    if not recipe:
        raise NotFoundRequest()
    recipe.checkAuthorized()
    recipe.delete()
    return jsonify({"msg": "DONE"})


@recipeHousehold.route("/search", methods=["GET"])
@jwt_required()
@authorize_household()
@validate_args(SearchByNameRequest)
def searchRecipeInHouseholdByName(args, household_id):
    if "only_ids" in args and args["only_ids"]:
        return jsonify([e.id for e in Recipe.search_name(args["query"], household_id)])
    return jsonify(
        [e.obj_to_full_dict() for e in Recipe.search_name(args["query"], household_id)]
    )


@recipeHousehold.route("/filter", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(GetAllFilterRequest)
def getAllFiltered(args, household_id):
    return jsonify(
        [
            e.obj_to_full_dict()
            for e in Recipe.all_by_name_with_filter(household_id, args["filter"])
        ]
    )


@recipeHousehold.route("/scrape", methods=["GET", "POST"])
@jwt_required()
@authorize_household()
@validate_args(ScrapeRecipe)
def scrapeRecipe(args, household_id):
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    res = scrape(args["url"], household)
    if res:
        return jsonify(res)
    return "Unsupported website", 400


@recipeHousehold.route("/scrape/pdf", methods=["POST"])
@jwt_required()
@authorize_household()
def scrapeRecipePdf(household_id):
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    if "file" not in request.files:
        return "Missing file", 400
    file = request.files["file"]
    if not file.filename or file.filename.rsplit(".", 1)[-1].lower() != "pdf":
        return "Unsupported PDF", 400

    text = extractPdfText(file.stream)
    res = extractRecipeFromText(text, household) if text else None
    if res:
        return jsonify(res)
    return "Unsupported PDF", 400


@recipeHousehold.route("/scrape/text", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(ScrapeRecipeText)
def scrapeRecipeText(args, household_id):
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    res = extractRecipeFromText(args["text"], household)
    if res:
        return jsonify(res)
    return "Unsupported text", 400


@recipe.route("/discover", methods=["GET"])
@jwt_required()
@validate_args(SuggestionsRecipe)
def suggestedRecipes(args):
    queryFilter = [Recipe.visibility == RecipeVisibility.PUBLIC]

    if "language" in args:
        queryFilter.append(Household.language == args["language"])

    tags = (
        RecipeTags.query.join(RecipeTags.tag)
        .join(RecipeTags.recipe)
        .join(Recipe.household)
        .with_entities(Tag.name, func.count().label("count"))
        .filter(*queryFilter)
        .group_by(Tag.name)
        .order_by(desc("count"))
        .limit(10)
        .all()
    )

    return jsonify(
        {
            "popular_tags": [e.name for e in tags],
            "curated": [
                e.obj_to_public_dict()
                for e in Recipe.query.join(Recipe.household)
                .filter(*queryFilter)
                .filter(Recipe.server_curated)
                .order_by(desc(Recipe.id))
                .limit(10)
                .all()
            ],
            "popular": [
                e.obj_to_public_dict()
                for e in Recipe.query.join(Recipe.household)
                .filter(*queryFilter)
                .order_by(
                    desc(Recipe.server_scrapes), Recipe.server_curated, desc(Recipe.id)
                )
                .limit(10)
                .all()
            ],
            "newest": [
                e.obj_to_public_dict()
                for e in Recipe.query.join(Recipe.household)
                .filter(*queryFilter)
                .order_by(desc(Recipe.id))
                .limit(10)
                .all()
            ],
        }
    )


@recipe.route("/discover/curated/<int:page>", methods=["GET"])
@jwt_required()
@validate_args(SuggestionsRecipe)
def curatedRecipes(args, page):
    queryFilter = [Recipe.visibility == RecipeVisibility.PUBLIC]

    if "language" in args:
        queryFilter.append(Household.language == args["language"])

    return jsonify(
        [
            e.obj_to_public_dict()
            for e in Recipe.query.join(Recipe.household)
            .filter(*queryFilter)
            .filter(Recipe.server_curated)
            .order_by(desc(Recipe.id))
            .offset(page * 10)
            .limit(10)
            .all()
        ]
    )


@recipe.route("/discover/popular/<int:page>", methods=["GET"])
@jwt_required()
@validate_args(SuggestionsRecipe)
def popularRecipes(args, page):
    queryFilter = [Recipe.visibility == RecipeVisibility.PUBLIC]

    if "language" in args:
        queryFilter.append(Household.language == args["language"])

    return jsonify(
        [
            e.obj_to_public_dict()
            for e in Recipe.query.join(Recipe.household)
            .filter(*queryFilter)
            .order_by(
                desc(Recipe.server_scrapes), Recipe.server_curated, desc(Recipe.id)
            )
            .offset(page * 10)
            .limit(10)
            .all()
        ]
    )


@recipe.route("/discover/newest/<int:page>", methods=["GET"])
@jwt_required()
@validate_args(SuggestionsRecipe)
def newestRecipes(args, page):
    queryFilter = [Recipe.visibility == RecipeVisibility.PUBLIC]

    if "language" in args:
        queryFilter.append(Household.language == args["language"])

    return jsonify(
        [
            e.obj_to_public_dict()
            for e in Recipe.query.join(Recipe.household)
            .filter(*queryFilter)
            .order_by(desc(Recipe.id))
            .offset(page * 10)
            .limit(10)
            .all()
        ]
    )


@recipe.route("/search", methods=["GET"])
@jwt_required()
@validate_args(SearchByNameRequest)
def searchAllRecipeByName(args):
    if "only_ids" in args and args["only_ids"]:
        return jsonify(
            [
                e.id
                for e in Recipe.search_name(
                    args["query"],
                    page=args["page"],
                    language=args["language"] if "language" in args else None,
                )
            ]
        )
    return jsonify(
        [
            e.obj_to_full_dict()
            for e in Recipe.search_name(
                args["query"],
                page=args["page"],
                language=args["language"] if "language" in args else None,
            )
        ]
    )


@recipe.route("/search-tag", methods=["GET"])
@jwt_required()
@validate_args(SearchByTagRequest)
def searchAllRecipeByTag(args):
    query = Recipe.query.filter(
        Recipe.visibility == RecipeVisibility.PUBLIC,
        Recipe.tags.any(
            RecipeTags.tag_id.in_(
                db.session.query(Tag.id)
                .filter(Tag.name == args["tag"])
                .scalar_subquery()
            )
        ),
    )
    if "language" in args:
        query = query.join(Recipe.household).filter(
            Household.language == args["language"]
        )

    return jsonify(
        [
            e.obj_to_full_dict()
            for e in query.order_by(Recipe.name)
            .offset(args["page"] * 10)
            .limit(10)
            .all()
        ]
    )
