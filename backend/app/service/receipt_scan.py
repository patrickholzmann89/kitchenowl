import base64
import json
from typing import Any, cast

from litellm import completion

from app.models import Household, Item
from app.service.ingredient_parsing import LLM_API_URL, LLM_MODEL

_SYSTEM_MESSAGE = """
You are a tool that extracts the purchased line items from a photo of a grocery receipt (Kassenbon) and returns only JSON in the form of [{"raw_text": string, "normalized_name": string, "price": number, "quantity": integer}, ...].

"raw_text" is the product text as printed on the receipt, unmodified. "normalized_name" is your best guess at a short, generic product name a shopper would use for this item (e.g. "Bio H-Milch NL 1L" -> "Milch"), in the same language as the receipt. "price" is the price of ONE pack/unit, as a plain number with a decimal point (if the printed price is a line total for multiple units, divide it by "quantity" to get the per-unit price). "quantity" is the number of units purchased, default 1 if not stated.

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
    result = json.loads(response.choices[0].message.content)
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
        lines.append(
            {
                "raw_text": str(entry["raw_text"])[:128],
                "normalized_name": str(entry.get("normalized_name") or entry["raw_text"])[
                    :128
                ],
                "price": price,
                "quantity": int(entry.get("quantity") or 1),
            }
        )
    return lines


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
            }
        )

    return {"lines": lines}
