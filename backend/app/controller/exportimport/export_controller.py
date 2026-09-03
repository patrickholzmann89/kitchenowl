from datetime import datetime
from flask import jsonify, Blueprint
from flask_jwt_extended import jwt_required
from app.errors import NotFoundRequest
from app.helpers import authorize_household
from app.models import Item, Recipe, Household, Category, Store, Tag, Shoppinglist, Planner

export = Blueprint("export", __name__)


@export.route("", methods=["GET"])
@jwt_required()
@authorize_household()
def getExportAll(household_id):
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    return household.obj_to_export_dict()


@export.route("/items", methods=["GET"])
@jwt_required()
@authorize_household()
def getExportItems(household_id):
    return jsonify(
        {
            "items": [
                e.obj_to_export_dict()
                for e in Item.all_from_household_by_name(household_id)
            ]
        }
    )


@export.route("/recipes", methods=["GET"])
@jwt_required()
@authorize_household()
def getExportRecipes(household_id):
    return jsonify(
        {
            "recipes": [
                e.obj_to_export_dict()
                for e in Recipe.all_from_household_by_name(household_id)
            ]
        }
    )


@export.route("/full", methods=["GET"])
@jwt_required()
@authorize_household()
def getExportFull(household_id):
    """
    Loss-less, id-based export of everything in a household (categories,
    stores, items with per-store prices, tags, recipes, shopping lists and
    planner entries) for migrating into another system over HTTP. Unlike
    getExportAll/getExportItems/getExportRecipes above, cross-references use
    the original numeric ids (not names) and prices/stores/shoppinglist and
    planner contents are included, none of which the name-based export
    supports. Photos are referenced by filename only - fetch their bytes
    from GET /api/upload/<filename> with the same bearer token.
    """
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    return jsonify(
        {
            "household": {
                "id": household.id,
                "name": household.name,
                "language": household.language,
                "description": household.description,
                "photo": household.photo,
                "planner_feature": household.planner_feature,
                "expenses_feature": household.expenses_feature,
                "pricing_feature": household.pricing_feature,
            },
            "categories": [
                {
                    "id": c.id,
                    "name": c.name,
                    "ordering": c.ordering,
                    "default_key": c.default_key,
                }
                for c in Category.all_by_ordering(household_id)
            ],
            "stores": [
                {"id": s.id, "name": s.name, "photo": s.photo}
                for s in Store.all_from_household_by_name(household_id)
            ],
            "items": [
                {
                    "id": i.id,
                    "name": i.name,
                    "icon": i.icon,
                    "photo": i.photo,
                    "category_id": i.category_id,
                    "piece_weight": i.piece_weight,
                    "ordering": i.ordering,
                    "prices": [
                        {
                            "store_id": p.store_id,
                            "price": p.price,
                            "pack_amount": p.pack_amount,
                            "pack_unit": p.pack_unit,
                            "sold_loose": p.sold_loose,
                            "external_ref": p.external_ref,
                        }
                        for p in i.prices
                    ],
                }
                for i in Item.all_from_household_by_name(household_id)
            ],
            "tags": [
                {"id": t.id, "name": t.name}
                for t in Tag.all_from_household_by_name(household_id)
            ],
            "recipes": [
                {
                    "id": r.id,
                    "name": r.name,
                    "description": r.description,
                    "photo": r.photo,
                    "time": r.time,
                    "cook_time": r.cook_time,
                    "prep_time": r.prep_time,
                    "yields": r.yields,
                    "source": r.source,
                    "visibility": r.visibility.name,
                    "items": [
                        {
                            "item_id": ri.item_id,
                            "description": ri.description,
                            "optional": ri.optional,
                            "amount": ri.amount,
                            "unit": ri.unit,
                        }
                        for ri in r.items
                    ],
                    "tags": [rt.tag_id for rt in r.tags],
                }
                for r in Recipe.all_from_household_by_name(household_id)
            ],
            "shoppinglists": [
                {
                    "id": sl.id,
                    "name": sl.name,
                    "items": [
                        {
                            "item_id": sli.item_id,
                            "description": sli.description,
                            "amount": sli.amount,
                            "unit": sli.unit,
                        }
                        for sli in sl.items
                    ],
                }
                for sl in Shoppinglist.all_from_household(household_id)
            ],
            "planner": [
                {
                    "recipe_id": p.recipe_id,
                    "cooking_date": p.cooking_date,
                    "yields": p.yields,
                }
                for p in Planner.all_from_household(household_id)
                if p.cooking_date > datetime.min
            ],
        }
    )
