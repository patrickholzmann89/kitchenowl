from datetime import datetime, timedelta, timezone


def _create_store(client, household_id, name):
    response = client.post(
        f"/api/household/{household_id}/store", json={"name": name}
    )
    assert response.status_code == 200, response.get_json()
    return response.get_json()["id"]


def _set_preferred_store(client, household_id, store_id):
    response = client.post(
        f"/api/household/{household_id}",
        json={"preferred_store_id": store_id, "pricing_feature": True},
    )
    assert response.status_code == 200, response.get_json()
    return response.get_json()


def test_store_crud(user_client_with_household, household_id):
    client = user_client_with_household

    store_id = _create_store(client, household_id, "Aldi")

    response = client.get(f"/api/household/{household_id}/store")
    assert response.status_code == 200
    stores = response.get_json()
    assert any(s["id"] == store_id and s["name"] == "Aldi" for s in stores)

    response = client.post(f"/api/store/{store_id}", json={"name": "Aldi Süd"})
    assert response.status_code == 200
    assert response.get_json()["name"] == "Aldi Süd"

    response = client.delete(f"/api/store/{store_id}")
    assert response.status_code == 200

    response = client.get(f"/api/household/{household_id}/store")
    assert response.get_json() == []


def test_deleting_preferred_store_unsets_it(user_client_with_household, household_id):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")
    _set_preferred_store(client, household_id, store_id)

    response = client.get(f"/api/household/{household_id}")
    assert response.get_json()["preferred_store_id"] == store_id

    response = client.delete(f"/api/store/{store_id}")
    assert response.status_code == 200

    response = client.get(f"/api/household/{household_id}")
    assert response.get_json()["preferred_store_id"] is None


def test_item_price_crud(user_client_with_household, household_id, item_id):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.5, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200, response.get_json()
    price = response.get_json()
    assert price["price"] == 0.5
    assert price["store"]["id"] == store_id

    # upsert: re-posting for the same (item, store) updates, not duplicates
    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.6, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    response = client.get(f"/api/item/{item_id}/price")
    assert response.status_code == 200
    prices = response.get_json()
    assert len(prices) == 1
    assert prices[0]["price"] == 0.6

    response = client.delete(f"/api/item/{item_id}/price/{store_id}")
    assert response.status_code == 200
    response = client.get(f"/api/item/{item_id}/price")
    assert response.get_json() == []


def test_sold_loose_price_is_proportional_not_rounded(
    user_client_with_household, household_id, item_id, item_name
):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Metzgerei")

    # 0.99 EUR per 100g, sold loose (deli counter) - no minimum pack
    response = client.post(
        f"/api/item/{item_id}/price",
        json={
            "store_id": store_id,
            "price": 0.99,
            "pack_amount": 100,
            "pack_unit": "g",
            "sold_loose": True,
        },
    )
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["sold_loose"] is True

    recipe_data = {
        "name": "Loose Recipe",
        "description": "",
        "yields": 1,
        "items": [
            {
                "name": item_name,
                "description": "137g",
                "optional": False,
                "amount": 137,
                "unit": "g",
            }
        ],
    }
    response = client.post(f"/api/household/{household_id}/recipe", json=recipe_data)
    assert response.status_code == 200
    recipe_id = response.get_json()["id"]

    _set_preferred_store(client, household_id, store_id)

    response = client.get(f"/api/recipe/{recipe_id}/cost")
    assert response.status_code == 200
    cost = response.get_json()
    # proportional: 137g / 100g * 0.99 = 1.3563, NOT rounded up to 200g worth
    assert abs(cost["total"] - (137 / 100 * 0.99)) < 1e-9, cost
    # exact_total matches total for loose goods - no rounding either way
    assert abs(cost["exact_total"] - cost["total"]) < 1e-9, cost


def test_recipe_cost_exact_total_ignores_pack_rounding(
    user_client_with_household, household_id, item_name
):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")
    _set_preferred_store(client, household_id, store_id)

    recipe_data = {
        "name": "Packaged Recipe",
        "description": "",
        "yields": 1,
        "items": [
            {
                "name": item_name,
                "description": "1 Stk",
                "optional": False,
                "amount": 1,
                "unit": "piece",
            }
        ],
    }
    response = client.post(f"/api/household/{household_id}/recipe", json=recipe_data)
    assert response.status_code == 200
    recipe = response.get_json()
    recipe_id = recipe["id"]
    item_id = recipe["items"][0]["id"]

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.6, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    response = client.get(f"/api/recipe/{recipe_id}/cost")
    assert response.status_code == 200
    cost = response.get_json()
    # total rounds up to a whole pack of 3 (0.60), exact_total is just 1/3 of a pack (0.20)
    assert abs(cost["total"] - 0.6) < 1e-9, cost
    assert abs(cost["exact_total"] - 0.2) < 1e-9, cost


def test_recipe_cost(user_client_with_household, household_id, item_name):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")
    _set_preferred_store(client, household_id, store_id)

    recipe_data = {
        "name": "Kostenrezept",
        "description": "",
        "yields": 2,
        "items": [
            {
                "name": item_name,
                "description": "1 Stk",
                "optional": False,
                "amount": 1,
                "unit": "piece",
            }
        ],
    }
    response = client.post(f"/api/household/{household_id}/recipe", json=recipe_data)
    assert response.status_code == 200
    recipe = response.get_json()
    recipe_id = recipe["id"]
    item_id = recipe["items"][0]["id"]

    # No cost yet - no price recorded
    response = client.get(f"/api/recipe/{recipe_id}/cost")
    assert response.status_code == 200
    assert response.get_json()["total"] is None

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.5, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    response = client.get(f"/api/recipe/{recipe_id}/cost")
    assert response.status_code == 200
    cost = response.get_json()
    assert cost["complete"] is True
    assert abs(cost["total"] - 0.5) < 1e-9

    # yields=4 doubles the amount needed (2 pieces) - still fits in 1 pack of 3
    response = client.get(f"/api/recipe/{recipe_id}/cost?yields=4")
    assert response.get_json()["total"] == 0.5

    # yields=8 -> 4 pieces needed -> 2 packs
    response = client.get(f"/api/recipe/{recipe_id}/cost?yields=8")
    assert response.get_json()["total"] == 1.0


def test_shoppinglist_cost(
    user_client_with_household, household_id, shoppinglist_id, item_id, item_name
):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")
    _set_preferred_store(client, household_id, store_id)

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.5, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    response = client.post(
        f"/api/shoppinglist/{shoppinglist_id}/item/{item_id}",
        json={"description": "1 Stk", "amount": 1, "unit": "piece"},
    )
    assert response.status_code == 200

    response = client.get(f"/api/shoppinglist/{shoppinglist_id}/cost")
    assert response.status_code == 200
    cost = response.get_json()
    assert cost["complete"] is True
    assert abs(cost["total"] - 0.5) < 1e-9


def test_add_recipe_items_merges_structured_amount(
    user_client_with_household, household_id, shoppinglist_id, recipe_with_items, item_name
):
    client = user_client_with_household

    # get the recipe item id
    response = client.get(f"/api/recipe/{recipe_with_items}")
    assert response.status_code == 200
    recipe = response.get_json()
    item_id = recipe["items"][0]["id"]

    response = client.post(
        f"/api/shoppinglist/{shoppinglist_id}/recipeitems",
        json={
            "items": [
                {"id": item_id, "name": item_name, "description": "1 Stk", "amount": 1, "unit": "piece"}
            ]
        },
    )
    assert response.status_code == 200

    response = client.post(
        f"/api/shoppinglist/{shoppinglist_id}/recipeitems",
        json={
            "items": [
                {"id": item_id, "name": item_name, "description": "2 Stk", "amount": 2, "unit": "piece"}
            ]
        },
    )
    assert response.status_code == 200

    response = client.get(f"/api/shoppinglist/{shoppinglist_id}/items")
    assert response.status_code == 200
    items = response.get_json()
    assert len(items) == 1
    assert items[0]["amount"] == 3
    assert items[0]["unit"] == "piece"


def test_planner_weekly_cost_aggregates_across_recipes(
    user_client_with_household, household_id, item_name
):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")
    _set_preferred_store(client, household_id, store_id)

    def make_recipe(name, amount):
        data = {
            "name": name,
            "description": "",
            "yields": 1,
            "items": [
                {
                    "name": item_name,
                    "description": f"{amount} Stk",
                    "optional": False,
                    "amount": amount,
                    "unit": "piece",
                }
            ],
        }
        response = client.post(f"/api/household/{household_id}/recipe", json=data)
        assert response.status_code == 200
        r = response.get_json()
        return r["id"], r["items"][0]["id"]

    recipe1_id, item_id = make_recipe("Recipe1", 1)
    recipe2_id, _ = make_recipe("Recipe2", 2)

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.5, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    now = datetime.now(timezone.utc)
    for recipe_id, offset in [(recipe1_id, 0), (recipe2_id, 1)]:
        cooking_date = int((now + timedelta(days=offset)).timestamp() * 1000)
        response = client.post(
            f"/api/household/{household_id}/planner/recipe",
            json={"recipe_id": recipe_id, "cooking_date": cooking_date, "yields": 1},
        )
        assert response.status_code == 200

    start = int((now - timedelta(days=1)).timestamp() * 1000)
    end = int((now + timedelta(days=3)).timestamp() * 1000)
    response = client.get(
        f"/api/household/{household_id}/planner/cost?start={start}&end={end}"
    )
    assert response.status_code == 200
    cost = response.get_json()
    # 1 + 2 = 3 pieces total = exactly 1 pack of 3, not 2 separately-rounded packs
    assert abs(cost["total"] - 0.5) < 1e-9, cost


def test_item_merge_preserves_price(user_client_with_household, household_id, item_id, item_name):
    client = user_client_with_household
    store_id = _create_store(client, household_id, "Aldi")

    response = client.post(
        f"/api/item/{item_id}/price",
        json={"store_id": store_id, "price": 0.5, "pack_amount": 3, "pack_unit": "piece"},
    )
    assert response.status_code == 200

    response = client.post(f"/api/household/{household_id}/item", json={"name": "Other Item"})
    assert response.status_code == 200
    other_item_id = response.get_json()["id"]

    response = client.post(
        f"/api/item/{other_item_id}", json={"merge_item_id": item_id}
    )
    assert response.status_code == 200

    response = client.get(f"/api/item/{other_item_id}/price")
    assert response.status_code == 200
    prices = response.get_json()
    assert len(prices) == 1
    assert prices[0]["price"] == 0.5
