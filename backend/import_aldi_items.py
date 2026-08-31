import argparse

from app import app
from app.models import Household, Item, Store
from app.models.store import ItemPrice

# Snapshot from https://aldi-preis.de/ (2026-08-31). Prices are ALDI's current
# listed price and fluctuate with offers; piece_weight is the average weight
# in grams of a single "Stück" as used in recipes (None where the item is
# always used/priced by weight or volume).
ALDI_ITEMS = [
    {"name": "Vollmilch", "price": 1.19, "pack_amount": 1, "pack_unit": "l"},
    {"name": "Eier", "price": 3.99, "pack_amount": 10, "pack_unit": "piece", "piece_weight": 60},
    {"name": "Butter", "price": 1.05, "pack_amount": 250, "pack_unit": "g"},
    {"name": "Bananen", "price": 1.29, "pack_amount": 3, "pack_unit": "piece", "piece_weight": 120},
    {"name": "Äpfel", "price": 1.69, "pack_amount": 1, "pack_unit": "kg", "piece_weight": 180},
    {"name": "Mischbrot", "price": 1.39, "pack_amount": 400, "pack_unit": "g"},
    {"name": "Gouda", "price": 4.29, "pack_amount": 450, "pack_unit": "g"},
    {"name": "Naturjoghurt", "price": 0.89, "pack_amount": 500, "pack_unit": "g"},
    {"name": "Kartoffeln", "price": 2.19, "pack_amount": 2.5, "pack_unit": "kg", "piece_weight": 120},
    {"name": "Zwiebeln", "price": 1.29, "pack_amount": 1, "pack_unit": "kg", "piece_weight": 80},
    {"name": "Tomaten", "price": 1.29, "pack_amount": 500, "pack_unit": "g", "piece_weight": 90},
    {"name": "Gurke", "price": 0.79, "pack_amount": 1, "pack_unit": "piece", "piece_weight": 400},
    {"name": "Paprika", "price": 1.35, "pack_amount": 500, "pack_unit": "g", "piece_weight": 150},
    {"name": "Hähnchenbrustfilet", "price": 9.99, "pack_amount": 1, "pack_unit": "kg"},
    {"name": "Hackfleisch", "price": 5.79, "pack_amount": 500, "pack_unit": "g"},
    {"name": "Bandnudeln", "price": 1.19, "pack_amount": 500, "pack_unit": "g"},
    {"name": "Basmati Reis", "price": 2.49, "pack_amount": 1, "pack_unit": "kg"},
    {"name": "Zucker", "price": 0.99, "pack_amount": 1, "pack_unit": "kg"},
    {"name": "Weizenmehl", "price": 0.59, "pack_amount": 1, "pack_unit": "kg"},
    {"name": "Karotten", "price": 1.59, "pack_amount": 1, "pack_unit": "kg", "piece_weight": 70},
    {"name": "Knoblauchzehe", "price": 0.89, "pack_amount": 200, "pack_unit": "g", "piece_weight": 5},
    {"name": "Zitronen", "price": 1.89, "pack_amount": 750, "pack_unit": "g", "piece_weight": 110},
    {"name": "Olivenöl", "price": 5.99, "pack_amount": 500, "pack_unit": "ml"},
    {"name": "Salz", "price": 0.29, "pack_amount": 500, "pack_unit": "g"},
    {"name": "Schlagsahne", "price": 0.89, "pack_amount": 200, "pack_unit": "g"},
    {"name": "Schweineschnitzel", "price": 4.59, "pack_amount": 500, "pack_unit": "g"},
    {"name": "Frischkäse", "price": 1.59, "pack_amount": 300, "pack_unit": "g"},
]


def import_items(household_id: int) -> None:
    household = Household.find_by_id(household_id)
    if not household:
        raise SystemExit(f"Household {household_id} not found")

    store = Store.find_by_name(household.id, "Aldi")
    if not store:
        store = Store(name="Aldi", household_id=household.id).save()
        print(f"Created store 'Aldi' (id={store.id})")

    for entry in ALDI_ITEMS:
        item = Item.find_by_name(household.id, entry["name"])
        if not item:
            item = Item.create_by_name(household.id, entry["name"])
            print(f"Created item '{item.name}' (id={item.id})")

        piece_weight = entry.get("piece_weight")
        if piece_weight is not None and item.piece_weight != piece_weight:
            item.piece_weight = piece_weight
            item.save(keepDefault=True)

        price = ItemPrice.find_by_item_store(item.id, store.id)
        if not price:
            price = ItemPrice(item_id=item.id, store_id=store.id, household_id=household.id)
        price.price = entry["price"]
        price.pack_amount = entry["pack_amount"]
        price.pack_unit = entry["pack_unit"]
        price.save()
        print(
            f"  price: {entry['name']} @ Aldi = {entry['price']} EUR / "
            f"{entry['pack_amount']} {entry['pack_unit']}"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="python import_aldi_items.py",
        description="Imports common ALDI grocery items with price and average "
        "piece weight (sourced from aldi-preis.de) into a household, assigned "
        "to a store named 'Aldi'.",
    )
    parser.add_argument(
        "household_id", type=int, help="id of the household to import the items into"
    )
    args = parser.parse_args()
    with app.app_context():
        import_items(args.household_id)
