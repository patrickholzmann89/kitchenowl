from typing import Any

import requests

from app.models import Item, ItemPrice
from app.service.aldi_price_search import _parsePackSize as _parseAldiPackSize
from app.service.dm_price_search import searchDmArticles

_ALDI_ARTICLE_URL = "https://aldi-preis.de/api/articles/{id}"
_TIMEOUT = 5


def eligible_price_ids(household_id: int) -> list[int]:
    """Prices that can be auto-refreshed: linked to a store literally named
    "Aldi" or "dm" (the same name matching AldiSearchCubit/DmSearchCubit use
    to auto-create that store) and carrying an external_ref captured at
    search time - prices set before this feature existed, or entered
    manually, have no external_ref and are left alone."""
    return [
        price.id
        for price in ItemPrice.query.filter(
            ItemPrice.household_id == household_id,
            ItemPrice.external_ref.isnot(None),
        ).all()
        if price.store.name.lower() in ("aldi", "dm")
    ]


def _refreshAldi(price: ItemPrice) -> bool:
    response = requests.get(
        _ALDI_ARTICLE_URL.format(id=price.external_ref), timeout=_TIMEOUT
    )
    if response.status_code == 404:
        return False
    response.raise_for_status()
    article = response.json()

    prices = article.get("prices") or []
    if not prices:
        return False
    latest = max(prices, key=lambda p: p["createdAt"])

    price.price = latest["price"]
    title = article.get("title")
    if title:
        price.pack_amount, price.pack_unit = _parseAldiPackSize(title)
    return True


def _refreshDm(price: ItemPrice, item: Item) -> bool:
    match = next(
        (
            r
            for r in searchDmArticles(item.name)
            if r.get("external_ref") == price.external_ref
        ),
        None,
    )
    if match is None:
        return False

    price.price = match["price"]
    price.pack_amount = match["pack_amount"]
    price.pack_unit = match["pack_unit"]
    return True


def refresh_batch(price_ids: list[int]) -> dict[str, Any]:
    refreshed = 0
    failed = 0
    for price_id in price_ids:
        price = ItemPrice.find_by_id(price_id)
        if not price or not price.external_ref:
            continue
        try:
            provider = price.store.name.lower()
            if provider == "aldi":
                changed = _refreshAldi(price)
            elif provider == "dm":
                changed = _refreshDm(price, price.item)
            else:
                continue
            if changed:
                price.save()
                refreshed += 1
        except Exception as e:
            failed += 1
            print(f"Error refreshing price {price_id}:", e)

    return {"refreshed": refreshed, "failed": failed}
