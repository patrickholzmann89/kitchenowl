import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/recipe_scraper_cubit.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class RecipeTextScraperCubit extends Cubit<RecipeScraperState> {
  final String text;
  final Household household;

  RecipeTextScraperCubit(this.household, this.text)
      : super(RecipeScraperLoadingState()) {
    scrapeRecipeText();
  }

  Future<void> scrapeRecipeText() async {
    final res = await ApiService.getInstance().scrapeRecipeText(
      household,
      text,
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
        // A scraped ingredient not yet linked to a household item (see
        // StringItemMatch._isLinked) only carries the parsed amount/unit
        // for prefilling once linked - it isn't a confirmed item yet.
        .where((e) => e?.id != null)
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
