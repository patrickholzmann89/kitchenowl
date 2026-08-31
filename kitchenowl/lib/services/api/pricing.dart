import 'dart:convert';

import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class CostEstimate {
  final double? total;
  // Proportional cost of exactly the amount needed, ignoring pack rounding.
  // Only populated for recipe cost estimates.
  final double? exactTotal;
  final bool complete;
  final int pricedItems;
  final int totalItems;

  const CostEstimate({
    this.total,
    this.exactTotal,
    this.complete = false,
    this.pricedItems = 0,
    this.totalItems = 0,
  });

  factory CostEstimate.fromJson(Map<String, dynamic> map) => CostEstimate(
        total: (map['total'] as num?)?.toDouble(),
        exactTotal: (map['exact_total'] as num?)?.toDouble(),
        complete: map['complete'] ?? false,
        pricedItems: map['priced_items'] ?? 0,
        totalItems: map['total_items'] ?? 0,
      );

  static const CostEstimate unavailable = CostEstimate();
}

extension PricingApi on ApiService {
  static const storeRoute = '/store';

  Future<List<Store>?> getStores(Household household) async {
    final res = await get(householdPath(household) + storeRoute);
    if (res.statusCode != 200) return null;

    return List<Store>.from(
      jsonDecode(res.body).map((e) => Store.fromJson(e)),
    );
  }

  Future<bool> addStore(Household household, Store store) async {
    final res = await post(
      householdPath(household) + storeRoute,
      jsonEncode(store.toJson()),
    );

    return res.statusCode == 200;
  }

  Future<bool> updateStore(Store store) async {
    final res = await post(
      '$storeRoute/${store.id}',
      jsonEncode(store.toJson()),
    );

    return res.statusCode == 200;
  }

  Future<bool> deleteStore(Store store) async {
    final res = await delete('$storeRoute/${store.id}');

    return res.statusCode == 200;
  }

  Future<List<ItemPrice>?> getItemPrices(Item item) async {
    final res = await get('/item/${item.id}/price');
    if (res.statusCode != 200) return null;

    return List<ItemPrice>.from(
      jsonDecode(res.body).map((e) => ItemPrice.fromJson(e)),
    );
  }

  Future<bool> addOrUpdateItemPrice(Item item, ItemPrice price) async {
    final res = await post(
      '/item/${item.id}/price',
      jsonEncode(price.toJson()),
    );

    return res.statusCode == 200;
  }

  Future<bool> deleteItemPrice(Item item, Store store) async {
    final res = await delete('/item/${item.id}/price/${store.id}');

    return res.statusCode == 200;
  }

  Future<CostEstimate> getRecipeCost(Recipe recipe, {int? yields}) async {
    String url = '/recipe/${recipe.id}/cost';
    if (yields != null) {
      url += '?yields=$yields';
    }
    final res = await get(url);
    if (res.statusCode != 200) return CostEstimate.unavailable;

    return CostEstimate.fromJson(jsonDecode(res.body));
  }

  Future<CostEstimate> getShoppinglistCost(ShoppingList shoppinglist) async {
    final res = await get('/shoppinglist/${shoppinglist.id}/cost');
    if (res.statusCode != 200) return CostEstimate.unavailable;

    return CostEstimate.fromJson(jsonDecode(res.body));
  }

  Future<CostEstimate> getPlannerCost(
    Household household,
    DateTime start,
    DateTime end,
  ) async {
    final url = '${householdPath(household)}/planner/cost'
        '?start=${start.toUtc().millisecondsSinceEpoch}'
        '&end=${end.toUtc().millisecondsSinceEpoch}';
    final res = await get(url);
    if (res.statusCode != 200) return CostEstimate.unavailable;

    return CostEstimate.fromJson(jsonDecode(res.body));
  }
}
