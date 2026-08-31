import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/models/receipt_scrape.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/api/pricing.dart';
import 'package:kitchenowl/services/api/receipt.dart';

abstract class ReceiptScraperState extends Equatable {
  const ReceiptScraperState();

  @override
  List<Object?> get props => [];
}

class ReceiptScraperLoadingState extends ReceiptScraperState {}

class ReceiptScraperErrorState extends ReceiptScraperState {}

class ReceiptScraperUnsupportedState extends ReceiptScraperState {}

class ReceiptScraperLoadedState extends ReceiptScraperState {
  final List<ReceiptLineItem> lines;
  final List<Store> stores;
  final Store? selectedStore;
  final Set<int> excludedIndices;

  const ReceiptScraperLoadedState({
    required this.lines,
    required this.stores,
    this.selectedStore,
    this.excludedIndices = const {},
  });

  ReceiptScraperLoadedState copyWith({
    List<ReceiptLineItem>? lines,
    Store? selectedStore,
    Set<int>? excludedIndices,
  }) =>
      ReceiptScraperLoadedState(
        lines: lines ?? this.lines,
        stores: stores,
        selectedStore: selectedStore ?? this.selectedStore,
        excludedIndices: excludedIndices ?? this.excludedIndices,
      );

  bool get isValid =>
      selectedStore != null &&
      lines.asMap().entries.any(
            (e) => !excludedIndices.contains(e.key) && e.value.item != null,
          );

  @override
  List<Object?> get props => [lines, stores, selectedStore, excludedIndices];
}

class ReceiptScraperCubit extends Cubit<ReceiptScraperState> {
  final Household household;
  final NamedByteArray file;

  ReceiptScraperCubit(this.household, this.file)
      : super(ReceiptScraperLoadingState()) {
    _load();
  }

  Future<void> _load() async {
    final scrapeFuture = ApiService.getInstance().scrapeReceipt(
      household,
      file,
    );
    final storesFuture = ApiService.getInstance().getStores(household);
    final scrapeResult = await scrapeFuture;
    final stores = await storesFuture;

    if (scrapeResult.$1 == null) {
      if (scrapeResult.$2 == 400) {
        emit(ReceiptScraperUnsupportedState());
      } else {
        emit(ReceiptScraperErrorState());
      }
      return;
    }

    emit(ReceiptScraperLoadedState(
      lines: scrapeResult.$1!.lines,
      stores: stores ?? const [],
      selectedStore: stores?.length == 1 ? stores!.first : null,
    ));
  }

  void updateItem(int index, Item? item) {
    final s = state;
    if (s is! ReceiptScraperLoadedState) return;
    final lines = List.of(s.lines);
    lines[index] = lines[index].copyWith(item: () => item);
    emit(s.copyWith(lines: lines));
  }

  void updatePrice(int index, ItemPrice price) {
    final s = state;
    if (s is! ReceiptScraperLoadedState) return;
    final lines = List.of(s.lines);
    lines[index] = lines[index].copyWith(price: price.price);
    emit(s.copyWith(
      lines: lines,
      selectedStore: price.store,
    ));
  }

  void updateStore(Store store) {
    final s = state;
    if (s is! ReceiptScraperLoadedState) return;
    emit(s.copyWith(selectedStore: store));
  }

  void toggleExcluded(int index) {
    final s = state;
    if (s is! ReceiptScraperLoadedState) return;
    final excluded = Set.of(s.excludedIndices);
    if (!excluded.add(index)) excluded.remove(index);
    emit(s.copyWith(excludedIndices: excluded));
  }

  Future<(int updated, int attempted)> confirm() async {
    final s = state;
    if (s is! ReceiptScraperLoadedState || !s.isValid) return (0, 0);

    int updated = 0;
    int attempted = 0;
    for (final entry in s.lines.asMap().entries) {
      if (s.excludedIndices.contains(entry.key)) continue;
      final item = entry.value.item;
      if (item == null) continue;

      attempted++;
      final success = await ApiService.getInstance().addOrUpdateItemPrice(
        item,
        ItemPrice(
          itemId: item.id ?? 0,
          store: s.selectedStore!,
          price: entry.value.price,
        ),
      );
      if (success) updated++;
    }

    return (updated, attempted);
  }
}
