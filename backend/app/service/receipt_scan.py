import base64
import json
import re
from typing import Any, cast

from litellm import completion

from app.models import Household, Item
from app.service.aldi_price_search import searchAldiArticles
from app.service.ingredient_parsing import LLM_API_URL, LLM_MODEL

# Models frequently wrap JSON responses in a markdown code fence despite
# being told to return raw JSON - strip it before parsing.
_CODE_FENCE_RE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


def _stripCodeFence(content: str) -> str:
    return _CODE_FENCE_RE.sub("", content.strip()).strip()

_SYSTEM_MESSAGE = """
You are a tool that extracts the purchased line items from a photo of a grocery receipt (Kassenbon) and returns only JSON in the form of [{"raw_text": string, "normalized_name": string, "price": number, "quantity": integer, "weight_grams": number|null}, ...].

"raw_text" is the product text as printed on the receipt, unmodified. "normalized_name" is your best guess at a short, generic product name a shopper would use for this item (e.g. "Bio H-Milch NL 1L" -> "Milch"), in the same language as the receipt. "price" is the price of ONE pack/unit, as a plain number with a decimal point (if the printed price is a line total for multiple units, divide it by "quantity" to get the per-unit price). "quantity" is the number of units purchased, default 1 if not stated. "weight_grams" is the total net weight in grams printed for this line if the receipt states one (e.g. a printed pack weight like "350g", or a weighed item shown as "0,450 kg x 2,99 EUR/kg"), converted to grams, or null if no weight is printed.

Do not include totals, subtotals, tax lines, deposits (Pfand), discounts, coupons, payment method, or any other non-product line.

Return only the JSON array and nothing else.
"""


def parseReceiptStructureLLM(imageBytes: bytes, mimeType: str) -> list[dict[str, Any]]:
    imageDataUrl = f"data:{mimeType};base64,{base64.b64encode(imageBytes).decode()}"
    messages = [
        {"role": "system", "content": _SYSTEM_MESSAGE},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Extract the line items from this receipt."},
                {"type": "image_url", "image_url": {"url": imageDataUrl}},
            ],
        },
    ]

    response = completion(
        model=cast(str, LLM_MODEL),
        api_base=LLM_API_URL,
        messages=messages,
    )
    content = response.choices[0].message.content or ""
    try:
        result = json.loads(_stripCodeFence(content))
    except json.JSONDecodeError:
        print("Receipt LLM returned non-JSON content:", content[:500])
        raise
    if not isinstance(result, list):
        return []

    lines = []
    for entry in result:
        if not isinstance(entry, dict) or not entry.get("raw_text"):
            continue
        try:
            price = float(entry.get("price"))
        except (TypeError, ValueError):
            continue
        try:
            weightGrams = float(entry["weight_grams"]) if entry.get("weight_grams") else None
        except (TypeError, ValueError):
            weightGrams = None
        lines.append(
            {
                "raw_text": str(entry["raw_text"])[:128],
                "normalized_name": str(entry.get("normalized_name") or entry["raw_text"])[
                    :128
                ],
                "price": price,
                "quantity": int(entry.get("quantity") or 1),
                "weight_grams": weightGrams,
            }
        )
    return lines


def _findPieceWeightOnline(normalizedName: str) -> float | None:
    try:
        for article in searchAldiArticles(normalizedName):
            if article.get("piece_weight"):
                return article["piece_weight"]
    except Exception as e:
        print("Error searching Aldi price tracker for piece weight:", e)
    return None


def _suggestPieceWeight(line: dict[str, Any], item: Item | None) -> float | None:
    if item is None or item.piece_weight is not None:
        return None
    if line["weight_grams"] and line["quantity"] > 0:
        return round(line["weight_grams"] / line["quantity"], 1)
    return _findPieceWeightOnline(line["normalized_name"])


def extractReceiptFromImage(
    imageBytes: bytes, mimeType: str, household: Household
) -> dict[str, Any]:
    parsedLines = parseReceiptStructureLLM(imageBytes, mimeType)

    lines = []
    for line in parsedLines:
        candidates = Item.search_name(line["normalized_name"], household.id)
        item = candidates[0] if candidates else None
        lines.append(
            {
                "raw_text": line["raw_text"],
                "normalized_name": line["normalized_name"],
                "price": line["price"],
                "quantity": line["quantity"],
                "item": item.obj_to_dict() if item else None,
                "piece_weight": _suggestPieceWeight(line, item),
            }
        )

    return {"lines": lines}
