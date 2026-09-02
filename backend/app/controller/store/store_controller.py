from app.helpers import validate_args, authorize_household
from app.helpers.authorize_household import RequiredRights
from flask import jsonify, Blueprint
from app.errors import NotFoundRequest, InvalidUsage
from flask_jwt_extended import jwt_required
from app.jobs.price_refresh_job import start_price_refresh
from app.models import Store, Household
from app.service.file_has_access_or_download import file_has_access_or_download
from .schemas import AddStore, UpdateStore

store = Blueprint("store", __name__)
storeHousehold = Blueprint("store", __name__)


@storeHousehold.route("", methods=["GET"])
@jwt_required()
@authorize_household()
def getAllStores(household_id):
    return jsonify(
        [e.obj_to_dict() for e in Store.all_from_household_by_name(household_id)]
    )


@storeHousehold.route("/refresh-prices", methods=["POST"])
@jwt_required()
@authorize_household(RequiredRights.ADMIN)
def refreshPrices(household_id):
    household = Household.find_by_id(household_id)
    if not household or not household.pricing_feature:
        raise InvalidUsage()

    total = start_price_refresh(household_id)
    return jsonify({"total": total})


@storeHousehold.route("", methods=["POST"])
@jwt_required()
@authorize_household()
@validate_args(AddStore)
def addStore(args, household_id):
    store = Store()
    store.name = args["name"]
    store.household_id = household_id
    if "photo" in args and args["photo"] != store.photo:
        store.photo = file_has_access_or_download(args["photo"], store.photo)
    store.save()
    return jsonify(store.obj_to_dict())


@store.route("/<int:id>", methods=["POST"])
@jwt_required()
@validate_args(UpdateStore)
def updateStore(args, id):
    store = Store.find_by_id(id)
    if not store:
        raise NotFoundRequest()
    store.checkAuthorized()

    if "name" in args:
        store.name = args["name"]
    if "photo" in args and args["photo"] != store.photo:
        store.photo = file_has_access_or_download(args["photo"], store.photo)
    store.save()

    return jsonify(store.obj_to_dict())


@store.route("/<int:id>", methods=["DELETE"])
@jwt_required()
def deleteStore(id):
    store = Store.find_by_id(id)
    if not store:
        raise NotFoundRequest()
    store.checkAuthorized()

    for household in Household.query.filter(
        Household.preferred_store_id == store.id
    ).all():
        household.preferred_store_id = None
        household.save()

    store.delete()
    return jsonify({"msg": "DONE"})
