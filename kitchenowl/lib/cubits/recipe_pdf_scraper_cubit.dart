import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/recipe_scraper_cubit.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class RecipePdfScraperCubit extends Cubit<RecipeScraperState> {
  final NamedByteArray file;
  final Household household;

  RecipePdfScraperCubit(this.household, this.file)
      : super(RecipeScraperLoadingState()) {
    scrapeRecipePdf();
  }

  Future<void> scrapeRecipePdf() async {
    final res = await ApiService.getInstance().scrapeRecipePdf(
      household,
      file,
    );

    if (res.$1 != null) {
      emit(RecipeScraperLoadedState.fromScrape(res.$1!));
    } else if (res.$2 == 400) {
      emit(RecipeScraperUnsupportedState());
    } else if (res.$2 == 403) {
      emit(RecipeScraperForbiddenState());
    } else {
      emit(RecipeScraperErrorState());
    }
  }

  void updateItem(String key, RecipeItem? item) {
    final _state = state;
    if (_state is RecipeScraperLoadedState) {
      final map = Map.of(_state.items);
      map[key] = item;
      emit(_state.copyWith(items: map));
    }
  }

  bool hasValidRecipe() {
    return state is RecipeScraperLoadedState &&
        (state as RecipeScraperLoadedState).isValid();
  }

  Recipe? getRecipe() {
    if (!hasValidRecipe()) return null;
    final items = (state as RecipeScraperLoadedState)
        .items
        .values
        .where((e) => e != null)
        .cast<RecipeItem>()
        .fold<List<RecipeItem>>(
      [],
      (l, e) => l.map((o) => o.name).contains(e.name) ? l : l + [e],
    ).toList();

    return (state as RecipeScraperLoadedState).recipe.copyWith(
          items: items,
        );
  }
}
