import re
from typing import Any

import requests

from app.util.units import G, KG, L, ML, PIECE

# Fixed, trusted host - no user-controlled URL, so a plain request is fine
# (unlike recipe_scraping.scrape(), which fetches arbitrary user-supplied URLs).
_SEARCH_URL = "https://aldi-preis.de/api/articles/search"
_TIMEOUT = 5

_WEIGHT_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(kg|g)\b", re.IGNORECASE)
_VOLUME_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(l|ml)\b", re.IGNORECASE)
_COUNT_RE = re.compile(r"(\d+)\s*(?:er[- ]?(?:packung)?|st(?:ü|u)ck)", re.IGNORECASE)
_PIECE_RANGE_RE = re.compile(r"(\d+)\s*-\s*(\d+)\s*st(?:ü|u)ck", re.IGNORECASE)


def _toFloat(s: str) -> float:
    return float(s.replace(",", "."))


def _parsePackSize(title: str) -> tuple[float, str]:
    match = _WEIGHT_RE.search(title)
    if match:
        return _toFloat(match.group(1)), (KG if match.group(2).lower() == "kg" else G)
    match = _VOLUME_RE.search(title)
    if match:
        return _toFloat(match.group(1)), (L if match.group(2).lower() == "l" else ML)
    match = _COUNT_RE.search(title)
    if match:
        return float(match.group(1)), PIECE
    return 1.0, PIECE


def _parsePieceWeight(title: str, packAmount: float, packUnit: str) -> float | None:
    if packUnit not in (G, KG):
        return None
    weightInGrams = packAmount * (1000 if packUnit == KG else 1)

    rangeMatch = _PIECE_RANGE_RE.search(title)
    if rangeMatch:
        count = (int(rangeMatch.group(1)) + int(rangeMatch.group(2))) / 2
    else:
        countMatch = _COUNT_RE.search(title)
        if not countMatch:
            return None
        count = int(countMatch.group(1))

    if count <= 0:
        return None
    return round(weightInGrams / count, 1)


def searchAldiArticles(query: str, limit: int = 10) -> list[dict[str, Any]]:
    response = requests.get(
        _SEARCH_URL, params={"q": query, "limit": limit}, timeout=_TIMEOUT
    )
    response.raise_for_status()

    results = []
    for article in response.json():
        title = article.get("title")
        price = article.get("currentPrice")
        if not title or price is None:
            continue
        packAmount, packUnit = _parsePackSize(title)
        results.append(
            {
                "title": title,
                "image_url": article.get("imageUrl"),
                "price": price,
                "pack_amount": packAmount,
                "pack_unit": packUnit,
                "piece_weight": _parsePieceWeight(title, packAmount, packUnit),
                # Lets app.service.price_refresh re-fetch this exact article
                # later via GET /api/articles/<id> instead of searching again.
                "external_ref": str(article["id"]) if "id" in article else None,
            }
        )
    return results
