import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/services/transactions/item.dart';
import 'package:kitchenowl/services/transactions/shoppinglist.dart';

class ItemEditCubit<T extends Item> extends Cubit<ItemEditState> {
  final Household? household;
  final T _item;
  final ShoppingList? shoppingList;

  T get item {
    if (_item is ItemWithDescription) {
      return (((_item as ItemWithDescription).copyWith(
        description: state.description,
        category: Nullable(state.category),
        icon: Nullable(state.icon),
        name: state.name,
        amount: Nullable(state.amount),
        unit: Nullable(state.unit),
        pieceWeight: Nullable(state.pieceWeight),
        photo: Nullable(state.photo),
      )) as T);
    }

    return _item.copyWith(
      category: Nullable(state.category),
      icon: Nullable(state.icon),
      name: state.name,
      pieceWeight: Nullable(state.pieceWeight),
      photo: Nullable(state.photo),
    ) as T;
  }

  ItemEditCubit({required T item, required this.household, this.shoppingList})
      : _item = item,
        super(ItemEditState(
          description: (item is ItemWithDescription) ? item.description : '',
          icon: item.icon,
          name: item.name,
          category: item.category,
          amount: (item is ItemWithDescription) ? item.amount : null,
          unit: (item is ItemWithDescription) ? item.unit : null,
          pieceWeight: item.pieceWeight,
          photo: item.photo,
        )) {
    refresh();
  }

  Future<void> refresh() async {
    if (_item.id != null) {
      final recipes = (await TransactionHandler.getInstance()
          .runTransaction(TransactionItemGetRecipes(
        household: household,
        item: _item,
      )))
        ..sort(((a, b) {
          if (a.isPlanned == b.isPlanned) {
            return 0;
          } else if (b.isPlanned) {
            return 1;
          } else {
            return -1;
          }
        }));
      emit(state.copyWith(recipes: recipes));

      if (_item is! RecipeItem) {
        final prices = await ApiService.getInstance().getItemPrices(_item);
        emit(state.copyWith(prices: prices ?? const []));

        if (household != null) {
          final stores = await ApiService.getInstance().getStores(household!);
          emit(state.copyWith(stores: stores ?? const []));
        }
      }
    }
  }

  Future<void> saveItem() async {
    if (state.pendingPhoto != null) {
      final pendingPhoto = state.pendingPhoto!;
      if (pendingPhoto.isEmpty) {
        emit(state.copyWith(
          photo: const Nullable(null),
          pendingPhoto: const Nullable(null),
        ));
      } else {
        final uploaded =
            await ApiService.getInstance().uploadBytes(pendingPhoto);
        emit(state.copyWith(
          photo: Nullable(uploaded ?? _item.photo),
          pendingPhoto: const Nullable(null),
        ));
      }
    }
    if (shoppingList != null &&
        (state.hasChangedDescription(_item) || state.hasChangedAmount(_item))) {
      await TransactionHandler.getInstance()
          .runTransaction(TransactionShoppingListUpdateItem(
        household: household!,
        shoppinglist: shoppingList!,
        item: _item,
        description: state.description,
        amount: state.amount,
        unit: state.unit,
      ));
    }
    if (state.hasChangedItem(_item)) {
      if (item.id != null) {
        await TransactionHandler.getInstance()
            .runTransaction(TransactionItemUpdate(
          item: item,
        ));
      } else if (household != null) {
        await TransactionHandler.getInstance()
            .runTransaction(TransactionItemAdd(
          household: household!,
          item: item,
        ));
      }
    }
  }

  Future<bool> deleteItem() async {
    if (_item.id != null) {
      return ApiService.getInstance().deleteItem(_item);
    }

    return false;
  }

  Future<bool> mergeItem(Item other) async {
    if (_item.id != null &&
        other.id != null &&
        await ApiService.getInstance().mergeItems(_item, other)) {
      emit(state.copyWith(hasMerged: true));
      return true;
    }

    return false;
  }

  void setName(String name) {
    emit(state.copyWith(name: name));
  }

  void setDescription(String desc) {
    emit(state.copyWith(description: desc));
  }

  void setCategory(Category? category) {
    emit(state.copyWith(
      category: Nullable(category),
    ));
  }

  void setIcon(String? icon) {
    emit(state.copyWith(
      icon: Nullable(icon),
    ));
  }

  void setAmount(double? amount) {
    emit(state.copyWith(amount: Nullable(amount)));
  }

  void setUnit(String? unit) {
    emit(state.copyWith(unit: Nullable(unit)));
  }

  void setPieceWeight(double? pieceWeight) {
    emit(state.copyWith(pieceWeight: Nullable(pieceWeight)));
  }

  void setPhoto(String? photo) {
    emit(state.copyWith(photo: Nullable(photo)));
  }

  void setPendingPhoto(NamedByteArray photo) {
    emit(state.copyWith(pendingPhoto: Nullable(photo)));
  }

  Future<bool> addOrUpdateItemPrice(ItemPrice price) async {
    if (_item.id == null) return false;
    final res =
        await ApiService.getInstance().addOrUpdateItemPrice(_item, price);
    refresh();

    return res;
  }

  Future<bool> deleteItemPrice(Store store) async {
    if (_item.id == null) return false;
    final res = await ApiService.getInstance().deleteItemPrice(_item, store);
    refresh();

    return res;
  }
}

class ItemEditState extends Equatable {
  final String name;
  final String description;
  final String? icon;
  final List<Recipe> recipes;
  final Category? category;
  final bool hasMerged;
  final double? amount;
  final String? unit;
  final double? pieceWeight;
  final String? photo;
  final NamedByteArray? pendingPhoto;
  final List<ItemPrice> prices;
  final List<Store> stores;

  const ItemEditState({
    this.name = "",
    this.description = "",
    this.icon,
    this.recipes = const [],
    this.category,
    this.hasMerged = false,
    this.amount,
    this.unit,
    this.pieceWeight,
    this.photo,
    this.pendingPhoto,
    this.prices = const [],
    this.stores = const [],
  });

  ItemEditState copyWith({
    String? name,
    String? description,
    Nullable<String>? icon,
    List<Recipe>? recipes,
    Nullable<Category>? category,
    bool? hasMerged,
    Nullable<double>? amount,
    Nullable<String>? unit,
    Nullable<double>? pieceWeight,
    Nullable<String>? photo,
    Nullable<NamedByteArray>? pendingPhoto,
    List<ItemPrice>? prices,
    List<Store>? stores,
  }) =>
      ItemEditState(
        name: name ?? this.name,
        description: description ?? this.description,
        icon: (icon ?? Nullable(this.icon)).value,
        recipes: recipes ?? this.recipes,
        category: (category ?? Nullable(this.category)).value,
        hasMerged: hasMerged ?? this.hasMerged,
        amount: (amount ?? Nullable(this.amount)).value,
        unit: (unit ?? Nullable(this.unit)).value,
        pieceWeight: (pieceWeight ?? Nullable(this.pieceWeight)).value,
        photo: (photo ?? Nullable(this.photo)).value,
        pendingPhoto: (pendingPhoto ?? Nullable(this.pendingPhoto)).value,
        prices: prices ?? this.prices,
        stores: stores ?? this.stores,
      );

  @override
  List<Object?> get props => [
        name,
        description,
        icon,
        recipes,
        category,
        hasMerged,
        amount,
        unit,
        pieceWeight,
        photo,
        pendingPhoto,
        prices,
        stores,
      ];

  bool hasChanged(Item comparedTo) =>
      hasChangedItem(comparedTo) ||
      hasChangedDescription(comparedTo) ||
      hasChangedAmount(comparedTo);

  bool hasChangedItem(Item comparedTo) =>
      comparedTo.category != category ||
      comparedTo.icon != icon ||
      comparedTo.name != name ||
      comparedTo.pieceWeight != pieceWeight ||
      comparedTo.photo != photo ||
      pendingPhoto != null ||
      hasMerged;

  bool hasChangedDescription(Item comparedTo) {
    return comparedTo is ItemWithDescription &&
        (comparedTo).description != description;
  }

  bool hasChangedAmount(Item comparedTo) {
    return comparedTo is ItemWithDescription &&
        (comparedTo.amount != amount || comparedTo.unit != unit);
  }
}
