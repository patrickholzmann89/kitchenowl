from flask import jsonify, Blueprint, request
from flask_jwt_extended import jwt_required

from app.errors import NotFoundRequest
from app.helpers import authorize_household
from app.models import Household
from app.service.ingredient_parsing import LLM_MODEL
from app.service.receipt_scan import extractReceiptFromImage

receiptHousehold = Blueprint("receipt", __name__)

_EXTENSION_MIME_TYPES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}


@receiptHousehold.route("/scrape", methods=["POST"])
@jwt_required()
@authorize_household()
def scrapeReceipt(household_id):
    household = Household.find_by_id(household_id)
    if not household:
        raise NotFoundRequest()

    if not LLM_MODEL:
        return "Receipt scanning requires a vision-capable LLM to be configured", 400

    if "file" not in request.files:
        return "Missing file", 400
    file = request.files["file"]
    extension = file.filename.rsplit(".", 1)[-1].lower() if file.filename else ""
    mimeType = _EXTENSION_MIME_TYPES.get(extension)
    if not mimeType:
        return "Unsupported image", 400

    try:
        res = extractReceiptFromImage(file.stream.read(), mimeType, household)
    except Exception as e:
        print("Error extracting receipt from image via LLM:", e)
        return "Unsupported receipt image", 400

    return jsonify(res)
