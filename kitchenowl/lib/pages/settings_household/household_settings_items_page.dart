import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_add_update/household_settings_items_cubit.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/pages/receipt_scraper_page.dart';
import 'package:kitchenowl/widgets/home_page/sliver_category_item_grid_list.dart';
import 'package:kitchenowl/widgets/item_popup_menu_button.dart';
import 'package:kitchenowl/widgets/select_file.dart';

class HouseholdSettingsItemsPage extends StatefulWidget {
  final Household household;

  const HouseholdSettingsItemsPage({
    super.key,
    required this.household,
  });

  @override
  State<HouseholdSettingsItemsPage> createState() =>
      _HouseholdSettingsItemsPageState();
}

class _HouseholdSettingsItemsPageState
    extends State<HouseholdSettingsItemsPage> {
  late HouseholdSettingsItemsCubit cubit;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cubit = HouseholdSettingsItemsCubit(widget.household);
  }

  @override
  void dispose() {
    cubit.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HouseholdCubit(widget.household),
      child: Scaffold(
        body: BlocBuilder<HouseholdSettingsItemsCubit,
            HouseholdSettingsItemsState>(
          bloc: cubit,
          builder: (context, state) {
            dynamic body;
            final filteredItems = state.filteredItems;

            if (state.sorting != ShoppinglistSorting.category ||
                state is LoadingHouseholdSettingsItemsState &&
                    filteredItems.isEmpty) {
              body = SliverItemGridList(
                isLoading: state is LoadingHouseholdSettingsItemsState,
                items: filteredItems,
                categories: state.categories,
                onRefresh: cubit.refresh,
                extraOption: _itemPopmenuBuilder,
                shoppingListStyle: const ShoppingListStyle(
                  allRaised: true,
                  advancedItemView: true,
                ),
              );
            } else {
              List<Widget> grids = [];
              // add items from categories
              for (int i = 0; i < state.categories.length + 1; i++) {
                Category? category =
                    i < state.categories.length ? state.categories[i] : null;
                final List<Item> items = filteredItems
                    .where((e) => e.category == category)
                    .toList();
                if (items.isEmpty) continue;

                grids.add(SliverCategoryItemGridList(
                  name: category?.name ??
                      AppLocalizations.of(context)!.uncategorized,
                  isLoading: state is LoadingHouseholdSettingsItemsState,
                  categories: state.categories,
                  onRefresh: cubit.refresh,
                  items: items,
                  extraOption: _itemPopmenuBuilder,
                  shoppingListStyle: const ShoppingListStyle(
                    allRaised: true,
                    advancedItemView: true,
                  ),
                ));
              }
              body = grids;
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(AppLocalizations.of(context)!.items),
                  floating: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt_rounded),
                      tooltip: AppLocalizations.of(context)!.receiptScan,
                      onPressed: () => _scanReceipt(context),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: BlocListener<HouseholdSettingsItemsCubit,
                        HouseholdSettingsItemsState>(
                      bloc: cubit,
                      listener: (context, state) {
                        if (state.query.isEmpty &&
                            searchController.text.isNotEmpty) {
                          searchController.clear();
                        }
                      },
                      listenWhen: (previous, current) =>
                          previous.query != current.query,
                      child: SearchTextField(
                        controller: searchController,
                        onSearch: (s) async => cubit.search(s),
                        clearOnSubmit: false,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: LeftRightWrap(
                    left: const SizedBox(),
                    right: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 6),
                      child: TrailingIconTextButton(
                        onPressed: cubit.incrementSorting,
                        text: state.sorting == ShoppinglistSorting.alphabetical
                            ? AppLocalizations.of(context)!.sortingAlphabetical
                            : state.sorting == ShoppinglistSorting.algorithmic
                                ? AppLocalizations.of(context)!
                                    .sortingAlgorithmic
                                : AppLocalizations.of(context)!.category,
                        icon: const Icon(Icons.sort),
                      ),
                    ),
                  ),
                ),
                if (body is List) ...body,
                if (body is! List) body,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _scanReceipt(BuildContext context) async {
    final file = await selectFile(
      context: context,
      title: AppLocalizations.of(context)!.receiptScan,
    );
    if (file == null || file.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ReceiptScraperPage(
        file: file,
        household: widget.household,
      ),
    ));
  }

  Widget _itemPopmenuBuilder(Item item) => ItemPopupMenuButton(
        item: item,
        household: widget.household,
        setIcon: (icon) => cubit.setIcon(item, icon),
        setName: (name) => cubit.setName(item, name),
        mergeItem: (other) => cubit.mergeItem(item, other),
        deleteItem: () => cubit.deleteItem(item),
      );
}
