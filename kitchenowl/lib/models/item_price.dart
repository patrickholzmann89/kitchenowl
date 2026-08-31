import 'package:kitchenowl/models/model.dart';
import 'package:kitchenowl/models/store.dart';

class ItemPrice extends Model {
  final int? id;
  final int itemId;
  final Store store;
  final double price;
  final double packAmount;
  final String packUnit;
  final bool soldLoose;

  const ItemPrice({
    this.id,
    required this.itemId,
    required this.store,
    required this.price,
    this.packAmount = 1,
    this.packUnit = "piece",
    this.soldLoose = false,
  });

  factory ItemPrice.fromJson(Map<String, dynamic> map) => ItemPrice(
        id: map['id'],
        itemId: map['item_id'],
        store: Store.fromJson(map['store']),
        price: (map['price'] as num).toDouble(),
        packAmount: (map['pack_amount'] as num).toDouble(),
        packUnit: map['pack_unit'] ?? "piece",
        soldLoose: map['sold_loose'] ?? false,
      );

  @override
  List<Object?> get props =>
      [id, itemId, store, price, packAmount, packUnit, soldLoose];

  @override
  Map<String, dynamic> toJson() => {
        "store_id": store.id,
        "price": price,
        "pack_amount": packAmount,
        "pack_unit": packUnit,
        "sold_loose": soldLoose,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
    });

  ItemPrice copyWith({
    Store? store,
    double? price,
    double? packAmount,
    String? packUnit,
    bool? soldLoose,
  }) =>
      ItemPrice(
        id: id,
        itemId: itemId,
        store: store ?? this.store,
        price: price ?? this.price,
        packAmount: packAmount ?? this.packAmount,
        packUnit: packUnit ?? this.packUnit,
        soldLoose: soldLoose ?? this.soldLoose,
      );
}
