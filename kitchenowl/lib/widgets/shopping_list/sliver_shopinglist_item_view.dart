import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/api/pricing.dart';
import 'package:kitchenowl/widgets/home_page/sliver_category_item_grid_list.dart';

class SliverShopinglistItemView extends StatelessWidget {
  final ShoppingList? shoppingList;
  final List<Category> categories;
  final void Function()? onRefresh;
  final Nullable<void Function(ShoppinglistItem)>? onPressed;
  final Nullable<void Function(ItemWithDescription)>? onRecentPressed;
  final ShoppinglistSorting sorting;
  final bool isLoading;
  final List<ShoppinglistItem> selectedListItems;
  final ShoppingListStyle shoppingListStyle;
  final CostEstimate costEstimate;
  final String? locale;

  const SliverShopinglistItemView({
    super.key,
    this.shoppingList,
    required this.categories,
    this.onRefresh,
    this.onPressed,
    this.onRecentPressed,
    required this.sorting,
    required this.isLoading,
    required this.selectedListItems,
    this.shoppingListStyle = const ShoppingListStyle(),
    this.costEstimate = CostEstimate.unavailable,
    this.locale,
  });

  bool Function(ShoppinglistItem) get _selected => (item) =>
      App.settings.shoppingListTapToRemove &&
          !App.settings.shoppingListListView ||
      !App.settings.shoppingListTapToRemove &&
          App.settings.shoppingListListView ^
              !selectedListItems.contains(item);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: locale);
    final priceLabels = <int, String>{
      for (final entry in costEstimate.lines.entries)
        entry.key: currency.format(entry.value.total),
    };

    dynamic main;
    final bool showFlat = isLoading && (shoppingList?.items.isEmpty ?? false);
    if (!showFlat && sorting == ShoppinglistSorting.category) {
      List<Widget> grids = [];
      // add items from categories
      for (int i = 0; i < categories.length + 1; i++) {
        Category? category = i < categories.length ? categories[i] : null;
        final List<ShoppinglistItem> items =
            shoppingList?.items.where((e) => e.category == category).toList() ??
                [];
        if (items.isEmpty) continue;

        grids.add(SliverCategoryItemGridList<ShoppinglistItem>(
          name: category?.name ?? AppLocalizations.of(context)!.uncategorized,
          items: items,
          categories: categories,
          shoppingList: shoppingList,
          selected: _selected,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onPressed: onPressed,
          shoppingListStyle: shoppingListStyle,
          priceLabels: priceLabels,
        ));
      }
      main = grids;
    } else if (!showFlat && sorting == ShoppinglistSorting.store) {
      // Which store each item should be bought at - resolved server-side
      // (household's preferred store, or whichever other store has the
      // cheapest price for that item), same data the price labels come from.
      final storeNames = <int, String>{
        for (final line in costEstimate.lines.values) line.storeId: line.storeName,
      };
      final storeIds = storeNames.keys.toList()
        ..sort((a, b) =>
            storeNames[a]!.toLowerCase().compareTo(storeNames[b]!.toLowerCase()));

      List<Widget> grids = [];
      for (final storeId in storeIds) {
        final items = shoppingList?.items
                .where((e) => costEstimate.lines[e.id]?.storeId == storeId)
                .toList() ??
            [];
        if (items.isEmpty) continue;

        grids.add(SliverCategoryItemGridList<ShoppinglistItem>(
          name: storeNames[storeId]!,
          items: items,
          categories: categories,
          shoppingList: shoppingList,
          selected: _selected,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onPressed: onPressed,
          shoppingListStyle: shoppingListStyle,
          priceLabels: priceLabels,
        ));
      }
      final unpriced = shoppingList?.items
              .where((e) => costEstimate.lines[e.id] == null)
              .toList() ??
          [];
      if (unpriced.isNotEmpty) {
        grids.add(SliverCategoryItemGridList<ShoppinglistItem>(
          name: AppLocalizations.of(context)!.priceUnavailable,
          items: unpriced,
          categories: categories,
          shoppingList: shoppingList,
          selected: _selected,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onPressed: onPressed,
          shoppingListStyle: shoppingListStyle,
          priceLabels: priceLabels,
        ));
      }
      main = grids;
    } else {
      main = SliverItemGridList<ShoppinglistItem>(
        items: shoppingList?.items ?? [],
        categories: categories,
        shoppingList: shoppingList,
        selected: _selected,
        isLoading: isLoading,
        onRefresh: onRefresh,
        onPressed: onPressed,
        shoppingListStyle: shoppingListStyle,
        priceLabels: priceLabels,
      );
    }
    return SliverMainAxisGroup(slivers: [
      if (main is List) ...main,
      if (main is! List) main,
      if (((shoppingList?.recentItems.isNotEmpty ?? false) &&
              (App.settings.recentItemsCount > 0)) ||
          isLoading)
        SliverCategoryItemGridList<ItemWithDescription>(
          name: '${AppLocalizations.of(context)!.itemsRecent}:',
          items: shoppingList?.recentItems
                  .take(App.settings.recentItemsCount)
                  .toList() ??
              [],
          onPressed: onRecentPressed,
          categories: categories,
          shoppingList: shoppingList,
          onRefresh: onRefresh,
          isLoading: isLoading,
          shoppingListStyle: shoppingListStyle,
          splitByCategories: App.settings.recentItemsCategorize &&
              !showFlat &&
              sorting == ShoppinglistSorting.category,
        ),
    ]);
  }
}
