import 'package:equatable/equatable.dart';
import 'package:kitchenowl/models/item.dart';

class ReceiptLineItem extends Equatable {
  final String rawText;
  final String normalizedName;
  final double price;
  final int quantity;
  final Item? item;
  final double? pieceWeight;

  const ReceiptLineItem({
    required this.rawText,
    required this.normalizedName,
    required this.price,
    required this.quantity,
    this.item,
    this.pieceWeight,
  });

  factory ReceiptLineItem.fromJson(Map<String, dynamic> map) =>
      ReceiptLineItem(
        rawText: map['raw_text'],
        normalizedName: map['normalized_name'],
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] ?? 1,
        item: map['item'] != null ? Item.fromJson(map['item']) : null,
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
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
        pieceWeight: pieceWeight,
      );

  @override
  List<Object?> get props =>
      [rawText, normalizedName, price, quantity, item, pieceWeight];
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
