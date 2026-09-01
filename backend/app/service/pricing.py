import math
from datetime import datetime
from typing import Any

from app.models import (
    Household,
    Item,
    ItemPrice,
    Planner,
    Recipe,
    Shoppinglist,
    ShoppinglistItems,
)
from app.util import units


def _bridge_kinds(
    base_amount: float,
    base_kind: str,
    pack_base_amount: float,
    pack_kind: str,
    piece_weight: float | None,
) -> tuple[float, float] | None:
    """Reconciles a recipe/shoppinglist amount and a pack size that are
    different kinds of unit (e.g. "300g" needed vs. a price given "per 3
    Stk") using the item's average piece weight (grams per piece), if known.
    Returns (base_amount, pack_base_amount) expressed in a common kind, or
    None if they can't be reconciled (different kinds and no piece_weight,
    or a kind pair piece_weight can't bridge, e.g. volume vs. count)."""
    if base_kind == pack_kind:
        return base_amount, pack_base_amount
    if not piece_weight or piece_weight <= 0:
        return None
    if base_kind == units.KIND_WEIGHT and pack_kind == units.KIND_COUNT:
        return base_amount, pack_base_amount * piece_weight
    if base_kind == units.KIND_COUNT and pack_kind == units.KIND_WEIGHT:
        return base_amount * piece_weight, pack_base_amount
    return None


def _priced_total(
    base_amount: float, price: ItemPrice, pack_base_amount: float
) -> tuple[float, int | None]:
    """Returns (total cost, packs bought - None for loose goods). Loose goods
    (price.sold_loose, e.g. deli counter items priced per 100g with no
    minimum purchase) scale proportionally to base_amount; packaged goods
    round up to whole packs since you can't buy a partial pack."""
    if price.sold_loose:
        return (base_amount / pack_base_amount) * price.price, None
    packs = math.ceil(base_amount / pack_base_amount)
    return packs * price.price, packs


def _resolve_price(
    item_id: int,
    preferred_store_id: int,
    base_amount: float,
    base_kind: str,
    piece_weight: float | None,
) -> tuple[ItemPrice, float, float] | None:
    """Picks which store's price to use for `amount`/`unit` (already
    expressed as base_amount/base_kind, see units.to_base): the preferred
    store's price if it has one, otherwise - among every other store that has
    a price for this item - whichever is cheapest per base unit. Returns
    (price, bridged_base_amount, bridged_pack_amount), or None if nothing is
    priced or bridgeable (see _bridge_kinds)."""
    preferred = ItemPrice.find_by_item_store(item_id, preferred_store_id)
    candidates = [preferred] if preferred else ItemPrice.all_by_item(item_id)

    best: tuple[float, ItemPrice, float, float] | None = None
    for price in candidates:
        pack_base = units.to_base(price.pack_amount, price.pack_unit)
        if pack_base is None:
            continue
        bridged = _bridge_kinds(
            base_amount, base_kind, pack_base[0], pack_base[1], piece_weight
        )
        if bridged is None:
            continue
        bridged_base_amount, bridged_pack_amount = bridged
        if bridged_pack_amount <= 0:
            continue
        unit_price = price.price / bridged_pack_amount
        if best is None or unit_price < best[0]:
            best = (unit_price, price, bridged_base_amount, bridged_pack_amount)

    if best is None:
        return None
    _, price, bridged_base_amount, bridged_pack_amount = best
    return price, bridged_base_amount, bridged_pack_amount


def resolve_default_pack_size(
    item_id: int, household: Household
) -> tuple[float, str] | None:
    """The pack size to default a shopping-list amount to when none is
    given: the preferred store's price for this item if it has one,
    otherwise the item's only price if it's priced at exactly one store -
    ambiguous (and thus skipped) if it's priced at several non-preferred
    stores, since there's no clear "the" pack size to pick then."""
    if not household.pricing_feature:
        return None

    price = None
    if household.preferred_store_id:
        price = ItemPrice.find_by_item_store(item_id, household.preferred_store_id)
    if not price:
        prices = ItemPrice.all_by_item(item_id)
        if len(prices) == 1:
            price = prices[0]
    if not price:
        return None

    return price.pack_amount, price.pack_unit


def compute_single_item_cost(
    item_id: int, amount: float | None, unit: str | None, store_id: int
) -> dict[str, Any] | None:
    """Cost for `amount` `unit` of an item, preferring `store_id` but falling
    back to the cheapest other store that has a price for it (see
    _resolve_price) - rounded up to whole packs, or proportional for loose
    goods (see _priced_total). None if the amount/unit isn't set, no store
    has a price for this item, or the units are different kinds (e.g. weight
    vs count) that can't be reconciled via the item's piece_weight."""
    if amount is None or unit is None:
        return None

    base = units.to_base(amount, unit)
    if base is None:
        return None

    item = Item.find_by_id(item_id)
    resolved = _resolve_price(
        item_id, store_id, base[0], base[1], item.piece_weight if item else None
    )
    if resolved is None:
        return None
    price, base_amount, pack_base_amount = resolved

    total, packs = _priced_total(base_amount, price, pack_base_amount)
    return {
        "total": total,
        # Proportional cost for exactly `amount`, ignoring pack rounding -
        # e.g. what the raw ingredients "are worth" even if you actually had
        # to buy whole packs to get them.
        "exact_total": (base_amount / pack_base_amount) * price.price,
        "packs": packs,
        "unit_price": price.price / pack_base_amount,
        "store_id": price.store_id,
        "store_name": price.store.name,
    }


def compute_recipe_cost(
    recipe: Recipe, store_id: int, yield_factor: float = 1.0
) -> dict[str, Any]:
    """Recipe-level estimate. `total` is rounded per recipe in isolation
    (i.e. assuming you're buying everything fresh, in whole packs, just for
    this recipe). `exact_total` is the proportional cost of exactly the
    amount needed, ignoring pack rounding - i.e. what the ingredients
    "are worth" regardless of how they'd actually have to be purchased."""
    total = 0.0
    exact_total = 0.0
    priced = 0
    required_items = [ri for ri in recipe.items if not ri.optional]

    for ri in required_items:
        amount = ri.amount * yield_factor if ri.amount is not None else None
        result = compute_single_item_cost(ri.item_id, amount, ri.unit, store_id)
        if result is None:
            continue
        total += result["total"]
        exact_total += result["exact_total"]
        priced += 1

    total_items = len(required_items)
    return {
        "total": total if priced > 0 else None,
        "exact_total": exact_total if priced > 0 else None,
        "complete": priced == total_items and total_items > 0,
        "priced_items": priced,
        "total_items": total_items,
    }


def compute_shoppinglist_cost(shoppinglist: Shoppinglist, store_id: int) -> dict[str, Any]:
    items = ShoppinglistItems.query.filter(
        ShoppinglistItems.shoppinglist_id == shoppinglist.id
    ).all()

    total = 0.0
    priced = 0
    lines: dict[int, dict[str, Any]] = {}
    by_store: dict[int, dict[str, Any]] = {}
    for si in items:
        result = compute_single_item_cost(si.item_id, si.amount, si.unit, store_id)
        if result is None:
            continue
        total += result["total"]
        priced += 1
        lines[si.item_id] = result

        store_total = by_store.setdefault(
            result["store_id"],
            {
                "store_id": result["store_id"],
                "store_name": result["store_name"],
                "total": 0.0,
                "priced_items": 0,
            },
        )
        store_total["total"] += result["total"]
        store_total["priced_items"] += 1

    return {
        "total": total if priced > 0 else None,
        "complete": priced == len(items) and len(items) > 0,
        "priced_items": priced,
        "total_items": len(items),
        "lines": lines,
        "by_store": sorted(
            by_store.values(), key=lambda s: s["total"], reverse=True
        ),
    }


def compute_weekly_cost(
    household_id: int, store_id: int, start: datetime, end: datetime
) -> dict[str, Any]:
    """Aggregates every planned recipe's (yield-scaled) ingredient amounts
    per item FIRST, then rounds to whole packs ONCE per item - so e.g. 1
    pepper needed by one planned recipe plus 2 more needed by another planned
    recipe in the same week combine to a true total of 3 (= exactly one pack
    of 3), instead of each recipe separately rounding up to its own pack."""
    plans = [
        p
        for p in Planner.all_from_household(household_id)
        if start <= p.cooking_date <= end
    ]

    aggregated: dict[tuple[int, str], float] = {}
    for plan in plans:
        recipe = plan.recipe
        factor = (
            plan.yields / recipe.yields
            if plan.yields and recipe.yields
            else 1.0
        )
        for ri in recipe.items:
            if ri.optional or ri.amount is None or ri.unit is None:
                continue
            base = units.to_base(ri.amount * factor, ri.unit)
            if base is None:
                continue
            base_amount, kind = base
            key = (ri.item_id, kind)
            aggregated[key] = aggregated.get(key, 0.0) + base_amount

    total = 0.0
    priced = 0
    lines: dict[int, dict[str, Any]] = {}
    for (item_id, kind), base_amount in aggregated.items():
        item = Item.find_by_id(item_id)
        resolved = _resolve_price(
            item_id, store_id, base_amount, kind, item.piece_weight if item else None
        )
        if resolved is None:
            continue
        price, bridged_amount, bridged_pack_amount = resolved
        line_total, packs = _priced_total(bridged_amount, price, bridged_pack_amount)
        total += line_total
        priced += 1
        lines[item_id] = {"total": line_total, "packs": packs}

    total_items = len(aggregated)
    return {
        "total": total if priced > 0 else None,
        "complete": priced == total_items and total_items > 0,
        "priced_items": priced,
        "total_items": total_items,
        "lines": lines,
    }
