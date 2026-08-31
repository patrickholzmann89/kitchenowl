import math
from datetime import datetime
from typing import Any

from app.models import ItemPrice, Planner, Recipe, Shoppinglist, ShoppinglistItems
from app.util import units


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


def compute_single_item_cost(
    item_id: int, amount: float | None, unit: str | None, store_id: int
) -> dict[str, Any] | None:
    """Cost for `amount` `unit` of an item at `store_id` - rounded up to
    whole packs, or proportional for loose goods (see _priced_total). None if
    the amount/unit isn't set, no price exists for that (item, store), or the
    units aren't the same kind (e.g. weight vs count)."""
    if amount is None or unit is None:
        return None
    price = ItemPrice.find_by_item_store(item_id, store_id)
    if not price:
        return None

    base = units.to_base(amount, unit)
    pack_base = units.to_base(price.pack_amount, price.pack_unit)
    if base is None or pack_base is None or base[1] != pack_base[1]:
        return None

    base_amount, _ = base
    pack_base_amount, _ = pack_base
    if pack_base_amount <= 0:
        return None

    total, packs = _priced_total(base_amount, price, pack_base_amount)
    return {
        "total": total,
        "packs": packs,
        "unit_price": price.price / pack_base_amount,
    }


def compute_recipe_cost(
    recipe: Recipe, store_id: int, yield_factor: float = 1.0
) -> dict[str, Any]:
    """Recipe-level estimate, rounded per recipe in isolation (i.e. assuming
    you're buying everything fresh just for this recipe)."""
    total = 0.0
    priced = 0
    required_items = [ri for ri in recipe.items if not ri.optional]

    for ri in required_items:
        amount = ri.amount * yield_factor if ri.amount is not None else None
        result = compute_single_item_cost(ri.item_id, amount, ri.unit, store_id)
        if result is None:
            continue
        total += result["total"]
        priced += 1

    total_items = len(required_items)
    return {
        "total": total if priced > 0 else None,
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
    for si in items:
        result = compute_single_item_cost(si.item_id, si.amount, si.unit, store_id)
        if result is None:
            continue
        total += result["total"]
        priced += 1
        lines[si.item_id] = result

    return {
        "total": total if priced > 0 else None,
        "complete": priced == len(items) and len(items) > 0,
        "priced_items": priced,
        "total_items": len(items),
        "lines": lines,
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
        price = ItemPrice.find_by_item_store(item_id, store_id)
        if not price:
            continue
        pack_base = units.to_base(price.pack_amount, price.pack_unit)
        if pack_base is None or pack_base[1] != kind or pack_base[0] <= 0:
            continue
        line_total, packs = _priced_total(base_amount, price, pack_base[0])
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
