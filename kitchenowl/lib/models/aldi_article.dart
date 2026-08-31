import 'package:equatable/equatable.dart';

class AldiArticle extends Equatable {
  final String title;
  final String? imageUrl;
  final double price;
  final double packAmount;
  final String packUnit;
  final double? pieceWeight;

  const AldiArticle({
    required this.title,
    this.imageUrl,
    required this.price,
    this.packAmount = 1,
    this.packUnit = "piece",
    this.pieceWeight,
  });

  factory AldiArticle.fromJson(Map<String, dynamic> map) => AldiArticle(
        title: map['title'],
        imageUrl: map['image_url'],
        price: (map['price'] as num).toDouble(),
        packAmount: (map['pack_amount'] as num).toDouble(),
        packUnit: map['pack_unit'] ?? "piece",
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
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
      );

  @override
  List<Object?> get props => [
        title,
        imageUrl,
        price,
        packAmount,
        packUnit,
        pieceWeight,
      ];
}
