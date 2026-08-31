import 'package:equatable/equatable.dart';
import 'package:kitchenowl/models/item.dart';

class ReceiptLineItem extends Equatable {
  final String rawText;
  final String normalizedName;
  final double price;
  final int quantity;
  final Item? item;

  const ReceiptLineItem({
    required this.rawText,
    required this.normalizedName,
    required this.price,
    required this.quantity,
    this.item,
  });

  factory ReceiptLineItem.fromJson(Map<String, dynamic> map) =>
      ReceiptLineItem(
        rawText: map['raw_text'],
        normalizedName: map['normalized_name'],
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] ?? 1,
        item: map['item'] != null ? Item.fromJson(map['item']) : null,
      );

  ReceiptLineItem copyWith({
    double? price,
    Item? Function()? item,
  }) =>
      ReceiptLineItem(
        rawText: rawText,
        normalizedName: normalizedName,
        price: price ?? this.price,
        quantity: quantity,
        item: item != null ? item() : this.item,
      );

  @override
  List<Object?> get props => [rawText, normalizedName, price, quantity, item];
}

class ReceiptScrape extends Equatable {
  final List<ReceiptLineItem> lines;

  const ReceiptScrape({required this.lines});

  factory ReceiptScrape.fromJson(Map<String, dynamic> map) => ReceiptScrape(
        lines: List<ReceiptLineItem>.from(
          (map['lines'] as List).map((e) => ReceiptLineItem.fromJson(e)),
        ),
      );

  @override
  List<Object?> get props => [lines];
}
