import 'package:fraction/fraction.dart';
import 'package:kitchenowl/helpers/string_scaler.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/model.dart';

import 'nullable.dart';

class Item extends Model {
  final int? id;
  final String name;
  final String? icon;
  final int ordering;
  final Category? category;
  final bool? isDefault;
  final String? defaultKey;
  // Average weight in grams of a single piece of this item (e.g. 1 bell
  // pepper =~ 150g) - lets the backend price a weight-based recipe amount
  // against a piece-based pack price.
  final double? pieceWeight;
  final String? photo;
  // The pack size this item is normally bought in (from the preferred
  // store's price, or its only price), only present on search results -
  // a hint for defaulting a shopping-list amount when none is given.
  final double? defaultAmount;
  final String? defaultUnit;

  const Item({
    this.id,
    required this.name,
    this.icon,
    this.ordering = 0,
    this.category,
    this.isDefault,
    this.defaultKey,
    this.pieceWeight,
    this.photo,
    this.defaultAmount,
    this.defaultUnit,
  });

  factory Item.fromItem({
    required Item item,
  }) =>
      Item(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        pieceWeight: item.pieceWeight,
        photo: item.photo,
        defaultAmount: item.defaultAmount,
        defaultUnit: item.defaultUnit,
      );

  factory Item.fromJson(Map<String, dynamic> map) => Item(
        id: map['id'],
        name: map['name'],
        ordering: map['ordering'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        icon: map['icon'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
        photo: map['photo'],
        defaultAmount: (map['default_amount'] as num?)?.toDouble(),
        defaultUnit: map['default_unit'],
      );

  Item copyWith({
    String? name,
    Nullable<Category>? category,
    Nullable<String>? icon,
    Nullable<double>? pieceWeight,
    Nullable<String>? photo,
  }) =>
      Item(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        ordering: ordering,
        pieceWeight: (pieceWeight ?? Nullable(this.pieceWeight)).value,
        photo: (photo ?? Nullable(this.photo)).value,
        defaultAmount: defaultAmount,
        defaultUnit: defaultUnit,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        ordering,
        isDefault,
        defaultKey,
        category,
        pieceWeight,
        photo,
        defaultAmount,
        defaultUnit,
      ];

  @override
  Map<String, dynamic> toJson() => {
        "name": name,
      };

  @override
  Map<String, dynamic> toJsonWithId() => toJson()
    ..addAll({
      "id": id,
      "ordering": ordering,
      "icon": icon,
      "category": category?.toJsonWithId(),
      "default": isDefault,
      "default_key": defaultKey,
      "piece_weight": pieceWeight,
      "photo": photo,
    });
}

class ItemWithDescription extends Item {
  final String description;
  final double? amount;
  final String? unit;

  const ItemWithDescription({
    super.id,
    required super.name,
    super.ordering = 0,
    super.icon,
    super.isDefault,
    super.defaultKey,
    super.category,
    super.pieceWeight,
    super.photo,
    super.defaultAmount,
    super.defaultUnit,
    this.description = '',
    this.amount,
    this.unit,
  });

  factory ItemWithDescription.fromJson(Map<String, dynamic> map) =>
      ItemWithDescription(
        id: map['id'],
        name: map['name'],
        description: map['description'] ?? "",
        amount: (map['amount'] as num?)?.toDouble(),
        unit: map['unit'],
        icon: map['icon'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
        photo: map['photo'],
        defaultAmount: (map['default_amount'] as num?)?.toDouble(),
        defaultUnit: map['default_unit'],
      );

  factory ItemWithDescription.fromItem({
    required Item item,
    String? description,
    double? amount,
    String? unit,
  }) =>
      ItemWithDescription(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        pieceWeight: item.pieceWeight,
        photo: item.photo,
        defaultAmount: item.defaultAmount,
        defaultUnit: item.defaultUnit,
        description: description ??
            ((item is ItemWithDescription) ? item.description : ''),
        amount: amount ?? (item is ItemWithDescription ? item.amount : null),
        unit: unit ?? (item is ItemWithDescription ? item.unit : null),
      );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "description": description,
      "amount": amount,
      "unit": unit,
    });

  @override
  ItemWithDescription copyWith({
    String? name,
    Nullable<Category>? category,
    Nullable<String>? icon,
    Nullable<double>? pieceWeight,
    Nullable<String>? photo,
    String? description,
    Nullable<double>? amount,
    Nullable<String>? unit,
  }) =>
      ItemWithDescription(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        pieceWeight: (pieceWeight ?? Nullable(this.pieceWeight)).value,
        photo: (photo ?? Nullable(this.photo)).value,
        description: description ?? this.description,
        amount: (amount ?? Nullable(this.amount)).value,
        unit: (unit ?? Nullable(this.unit)).value,
        ordering: ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
        defaultAmount: defaultAmount,
        defaultUnit: defaultUnit,
      );

  @override
  List<Object?> get props => super.props + [description, amount, unit];
}

class ShoppinglistItem extends ItemWithDescription {
  final int? createdById;
  final DateTime? createdAt;

  const ShoppinglistItem({
    super.id,
    required super.name,
    super.description = '',
    super.amount,
    super.unit,
    super.category,
    super.icon,
    super.ordering = 0,
    super.defaultKey,
    super.isDefault,
    super.pieceWeight,
    super.photo,
    this.createdById,
    this.createdAt,
  });

  factory ShoppinglistItem.fromJson(Map<String, dynamic> map) {
    return ShoppinglistItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      amount: (map['amount'] as num?)?.toDouble(),
      unit: map['unit'],
      ordering: map['ordering'],
      isDefault: map['default'],
      defaultKey: map['default_key'],
      icon: map['icon'],
      category:
          map['category'] != null ? Category.fromJson(map['category']) : null,
      pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
      photo: map['photo'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'], isUtc: true)
              .toLocal()
          : null,
      createdById: map['created_by'],
    );
  }

  /// Turn an Item into a Shopping list item.
  ///
  /// If description is null and item is an ItemWithDescription the existing description is used.
  factory ShoppinglistItem.fromItem({
    required Item item,
    String? description,
    DateTime? createdAt,
    int? createdById,
  }) =>
      ShoppinglistItem(
        id: item.id,
        name: item.name,
        icon: item.icon,
        description: description ??
            (item is ItemWithDescription ? item.description : ""),
        amount: item is ItemWithDescription ? item.amount : null,
        unit: item is ItemWithDescription ? item.unit : null,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        pieceWeight: item.pieceWeight,
        photo: item.photo,
        createdAt: createdAt ?? DateTime.now(),
        createdById: createdById,
      );

  @override
  ShoppinglistItem copyWith({
    String? name,
    Nullable<Category>? category,
    Nullable<String>? icon,
    Nullable<double>? pieceWeight,
    Nullable<String>? photo,
    String? description,
    Nullable<double>? amount,
    Nullable<String>? unit,
  }) =>
      ShoppinglistItem(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        pieceWeight: (pieceWeight ?? Nullable(this.pieceWeight)).value,
        photo: (photo ?? Nullable(this.photo)).value,
        description: description ?? this.description,
        amount: (amount ?? Nullable(this.amount)).value,
        unit: (unit ?? Nullable(this.unit)).value,
        ordering: ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
      );

  @override
  List<Object?> get props => super.props + [createdAt, createdById];

  @override
  Map<String, dynamic> toJsonWithId() => super.toJsonWithId()
    ..addAll({
      "created_at": createdAt?.toUtc().millisecondsSinceEpoch,
      "created_by": createdById,
    });
}

class RecipeItem extends ItemWithDescription {
  final bool optional;

  const RecipeItem({
    super.id,
    required super.name,
    super.description = '',
    super.amount,
    super.unit,
    super.ordering = 0,
    super.defaultKey,
    super.isDefault,
    super.category,
    super.icon,
    super.pieceWeight,
    super.photo,
    this.optional = false,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> map) => RecipeItem(
        id: map['id'],
        name: map['name'] ?? '',
        description: map['description'],
        amount: (map['amount'] as num?)?.toDouble(),
        unit: map['unit'],
        icon: map['icon'],
        isDefault: map['default'],
        defaultKey: map['default_key'],
        optional: map['optional'],
        category:
            map['category'] != null ? Category.fromJson(map['category']) : null,
        pieceWeight: (map['piece_weight'] as num?)?.toDouble(),
        photo: map['photo'],
      );

  factory RecipeItem.fromItem({
    required Item item,
    String description = '',
    double? amount,
    String? unit,
    bool optional = false,
  }) =>
      RecipeItem(
        id: item.id,
        name: item.name,
        icon: item.icon,
        category: item.category,
        ordering: item.ordering,
        isDefault: item.isDefault,
        defaultKey: item.defaultKey,
        pieceWeight: item.pieceWeight,
        photo: item.photo,
        description:
            item is ItemWithDescription ? item.description : description,
        amount: item is ItemWithDescription ? item.amount : amount,
        unit: item is ItemWithDescription ? item.unit : unit,
        optional: optional,
      );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      "optional": optional,
    });

  @override
  RecipeItem copyWith({
    String? name,
    Nullable<Category>? category,
    Nullable<String>? icon,
    Nullable<double>? pieceWeight,
    Nullable<String>? photo,
    String? description,
    Nullable<double>? amount,
    Nullable<String>? unit,
    bool? optional,
  }) =>
      RecipeItem(
        id: id,
        name: name ?? this.name,
        category: (category ?? Nullable(this.category)).value,
        icon: (icon ?? Nullable(this.icon)).value,
        pieceWeight: (pieceWeight ?? Nullable(this.pieceWeight)).value,
        photo: (photo ?? Nullable(this.photo)).value,
        description: description ?? this.description,
        amount: (amount ?? Nullable(this.amount)).value,
        unit: (unit ?? Nullable(this.unit)).value,
        optional: optional ?? this.optional,
        ordering: ordering,
        isDefault: isDefault,
        defaultKey: defaultKey,
      );

  RecipeItem withFactor(
    Fraction factor, {
    bool addDescriptionWhenEmpty = true,
  }) {
    final scaledAmount = amount != null ? amount! * factor.toDouble() : null;
    if (!addDescriptionWhenEmpty) {
      return copyWith(amount: Nullable(scaledAmount));
    }

    return copyWith(
      description: StringScaler.scale(description, factor),
      amount: Nullable(scaledAmount),
    );
  }

  Item toItem() => Item(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
        pieceWeight: pieceWeight,
        photo: photo,
      );

  ItemWithDescription toItemWithDescription() => ItemWithDescription(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
        pieceWeight: pieceWeight,
        photo: photo,
        description: description,
        amount: amount,
        unit: unit,
      );

  ShoppinglistItem toShoppingListItem() => ShoppinglistItem(
        id: id,
        name: name,
        icon: icon,
        ordering: ordering,
        defaultKey: defaultKey,
        isDefault: isDefault,
        category: category,
        pieceWeight: pieceWeight,
        photo: photo,
        description: description,
        amount: amount,
        unit: unit,
      );

  @override
  List<Object?> get props => super.props + [optional];
}
