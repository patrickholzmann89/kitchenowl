import 'package:equatable/equatable.dart';

class AldiArticle extends Equatable {
  final String title;
  final String? imageUrl;
  final double price;
  final double packAmount;
  final String packUnit;
  final double? pieceWeight;
  // The Aldi article id, used to re-fetch this exact product's current
  // price later (see app.service.price_refresh on the backend).
  final String? externalRef;

  const AldiArticle({
    required this.title,
    this.imageUrl,
    required this.price,
    this.packAmount = 1,
    this.packUnit = "piece",
    this.pieceWeight,
    this.externalRef,
  });

  factory AldiArticle.fromJson(Map<String, dynamic> map) => AldiArticle(
        title: map['title'],
        imageUrl: map['image_url'],
        price: (map['price'] as num).toDouble(),
        packAmount: (map['pack_amount'] as num).toDouble(),
        packUnit: map['pack_unit'] ?? "piece",
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
        externalRef: map['external_ref'],
      );

  AldiArticle copyWith({
    double? price,
    double? packAmount,
    String? packUnit,
    double? Function()? pieceWeight,
  }) =>
      AldiArticle(
        title: title,
        imageUrl: imageUrl,
        price: price ?? this.price,
        packAmount: packAmount ?? this.packAmount,
        packUnit: packUnit ?? this.packUnit,
        pieceWeight: pieceWeight != null ? pieceWeight() : this.pieceWeight,
        externalRef: externalRef,
      );

  @override
  List<Object?> get props => [
        title,
        imageUrl,
        price,
        packAmount,
        packUnit,
        pieceWeight,
        externalRef,
      ];
}
