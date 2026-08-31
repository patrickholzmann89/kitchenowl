import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/models/aldi_article.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/services/api/aldi.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/api/pricing.dart';

const String kAldiStoreName = "Aldi";

class AldiSearchState extends Equatable {
  final String query;
  final bool isLoading;
  final bool hasError;
  final List<AldiArticle> results;
  final List<Store> stores;

  const AldiSearchState({
    this.query = "",
    this.isLoading = true,
    this.hasError = false,
    this.results = const [],
    this.stores = const [],
  });

  AldiSearchState copyWith({
    String? query,
    bool? isLoading,
    bool? hasError,
    List<AldiArticle>? results,
    List<Store>? stores,
  }) =>
      AldiSearchState(
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        results: results ?? this.results,
        stores: stores ?? this.stores,
      );

  @override
  List<Object?> get props => [query, isLoading, hasError, results, stores];
}

class AldiSearchCubit extends Cubit<AldiSearchState> {
  final Household household;
  final Item item;

  AldiSearchCubit(this.household, this.item)
      : super(AldiSearchState(query: item.name)) {
    _loadStores();
    search(item.name);
  }

  Future<void> _loadStores() async {
    final stores = await ApiService.getInstance().getStores(household);
    emit(state.copyWith(stores: stores ?? const []));
  }

  Future<void> search(String query) async {
    if (query.trim().length < 2) {
      emit(state.copyWith(
        query: query,
        isLoading: false,
        hasError: false,
        results: const [],
      ));
      return;
    }
    emit(state.copyWith(query: query, isLoading: true, hasError: false));

    final results = await ApiService.getInstance().searchAldiArticles(
      item,
      query,
    );

    emit(state.copyWith(
      isLoading: false,
      hasError: results == null,
      results: results ?? const [],
    ));
  }

  // Finds the "Aldi" store, creating it in this household if it doesn't
  // exist yet, so a proposal can be applied without the user having to set
  // up the store manually first.
  Future<Store?> resolveAldiStore() async {
    Store? existing = state.stores.firstWhereOrNull(
      (s) => s.name.toLowerCase() == kAldiStoreName.toLowerCase(),
    );
    if (existing != null) return existing;

    final created = await ApiService.getInstance().addStore(
      household,
      const Store(name: kAldiStoreName),
    );
    if (!created) return null;

    final stores = await ApiService.getInstance().getStores(household);
    emit(state.copyWith(stores: stores ?? state.stores));

    return stores?.firstWhereOrNull(
      (s) => s.name.toLowerCase() == kAldiStoreName.toLowerCase(),
    );
  }
}
