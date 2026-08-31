"""Structured amount/unit helpers for the ingredient-pricing feature.

Mirrors the unit vocabulary used by app.util.description_merger (COUNT /
SI_WEIGHT / SI_VOLUME) but as plain, persistable values instead of a
free-text parse target - RecipeItems.amount/unit, ShoppinglistItems.amount/
unit and ItemPrice.pack_amount/pack_unit all use this vocabulary so their
values can be compared and summed directly.
"""

# COUNT
PIECE = "piece"
# WEIGHT (base unit: g)
MG = "mg"
G = "g"
KG = "kg"
# VOLUME (base unit: ml)
ML = "ml"
L = "l"

ALLOWED_UNITS = (PIECE, MG, G, KG, ML, L)

KIND_COUNT = "COUNT"
KIND_WEIGHT = "WEIGHT"
KIND_VOLUME = "VOLUME"

_UNIT_KIND = {
    PIECE: KIND_COUNT,
    MG: KIND_WEIGHT,
    G: KIND_WEIGHT,
    KG: KIND_WEIGHT,
    ML: KIND_VOLUME,
    L: KIND_VOLUME,
}

_TO_BASE_FACTOR = {
    PIECE: 1.0,
    MG: 1.0 / 1000,
    G: 1.0,
    KG: 1000.0,
    ML: 1.0,
    L: 1000.0,
}


def unit_kind(unit: str) -> str | None:
    return _UNIT_KIND.get(unit)


def to_base(amount: float, unit: str) -> tuple[float, str] | None:
    """Converts to the base unit for its kind (piece/g/ml). Returns None for
    an unrecognised unit."""
    kind = unit_kind(unit)
    if kind is None:
        return None
    return amount * _TO_BASE_FACTOR[unit], kind


def from_base(base_amount: float, kind: str) -> tuple[float, str]:
    """Simplifies a base-unit amount back to the nicest concrete unit,
    mirroring description_merger's merge_SI_Weight/merge_SI_Volume
    simplification (small weights -> mg, whole kg -> kg, else g)."""
    if kind == KIND_COUNT:
        return base_amount, PIECE
    if kind == KIND_WEIGHT:
        if base_amount < 1:
            return base_amount * 1000, MG
        if (base_amount / 1000).is_integer():
            return base_amount / 1000, KG
        return base_amount, G
    if kind == KIND_VOLUME:
        if (base_amount / 1000).is_integer():
            return base_amount / 1000, L
        return base_amount, ML
    raise ValueError(f"Unknown unit kind: {kind}")


def merge_structured_amount(
    base_amount: float | None,
    base_unit: str | None,
    add_amount: float | None,
    add_unit: str | None,
) -> tuple[float | None, str | None]:
    """Sums two structured amounts if they're the same kind of unit (e.g.
    both weights); otherwise returns (None, None) - the combined line falls
    back to "unknown/mixed" rather than guessing."""
    if base_amount is None or base_unit is None:
        return add_amount, add_unit
    if add_amount is None or add_unit is None:
        return base_amount, base_unit

    a = to_base(base_amount, base_unit)
    b = to_base(add_amount, add_unit)
    if a is None or b is None or a[1] != b[1]:
        return None, None

    return from_base(a[0] + b[0], a[1])
