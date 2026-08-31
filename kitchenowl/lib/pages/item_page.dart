import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/cubits/item_edit_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/helpers/build_context_extension.dart';
import 'package:kitchenowl/helpers/item_description_parser.dart';
import 'package:kitchenowl/helpers/units.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/models/update_value.dart';
import 'package:kitchenowl/widgets/item_popup_menu_button.dart';
import 'package:kitchenowl/widgets/item_price_dialog.dart';
import 'package:kitchenowl/widgets/item_wrap_menu.dart';
import 'package:kitchenowl/widgets/recipe_item.dart';

class ItemPage<T extends Item> extends StatefulWidget {
  final T item;
  final ShoppingList? shoppingList;
  final List<Category> categories;
  final bool advancedView;

  const ItemPage({
    super.key,
    required this.item,
    this.shoppingList,
    this.categories = const [],
    this.advancedView = false,
  });

  @override
  _ItemPageState createState() => _ItemPageState<T>();
}

class _ItemPageState<T extends Item> extends State<ItemPage<T>> {
  final TextEditingController descController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  late ItemEditCubit<T> cubit;

  @override
  void initState() {
    super.initState();
    if (widget.item is ItemWithDescription) {
      final item = widget.item as ItemWithDescription;
      descController.text = item.description;
      amountController.text = item.amount?.toString() ?? '';
    }
    cubit = ItemEditCubit<T>(
      household: context.read<HouseholdCubit>().state.household,
      item: widget.item,
      shoppingList: widget.shoppingList,
    );
  }

  @override
  void dispose() {
    cubit.close();
    descController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItemEditCubit, ItemEditState>(
      bloc: cubit,
      buildWhen: (prev, curr) =>
          prev.hasChanged(widget.item) != curr.hasChanged(widget.item),
      builder: (context, state) => PopScope(
        canPop: !state.hasChanged(widget.item),
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && state.hasChanged(widget.item)) {
            await cubit.saveItem();
            if (mounted) {
              Navigator.of(context)
                  .pop(UpdateValue<T>(UpdateEnum.updated, cubit.item));
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: BlocBuilder<ItemEditCubit, ItemEditState>(
              bloc: cubit,
              buildWhen: (prev, curr) => prev.name != curr.name,
              builder: (context, state) => Text(state.name),
            ),
            actions: [
              if (!App.isOffline)
                ItemPopupMenuButton(
                  item: cubit.item,
                  household: context.read<HouseholdCubit>().state.household,
                  setIcon: cubit.setIcon,
                  setName: cubit.setName,
                  mergeItem: cubit.mergeItem,
                  deleteItem: () async {
                    await cubit.deleteItem();
                    if (!mounted) return;
                    Navigator.of(context)
                        .pop(const UpdateValue<Item>(UpdateEnum.deleted));
                  },
                ),
            ],
          ),
          body: Scrollbar(
            child: RefreshIndicator(
              onRefresh: cubit.refresh,
              child: CustomScrollView(
                slivers: [
                  if (widget.item is ItemWithDescription)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: TextField(
                          autofocus: true,
                          controller: descController,
                          onChanged: (s) => cubit.setDescription(s),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14)),
                            ),
                            labelText:
                                AppLocalizations.of(context)!.description,
                            // suffix: IconButton(
                            //   onPressed: () {
                            //     if (descController.text.isNotEmpty) {
                            //       cubit.setDescription('');
                            //       descController.clear();
                            //     }
                            //     FocusScope.of(context).unfocus();
                            //   },
                            //   icon: Icon(
                            //     Icons.close,
                            //     color: Colors.grey,
                            //   ),
                            // ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.item is ItemWithDescription)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (s) => cubit
                                    .setAmount(double.tryParse(s.replaceAll(',', '.'))),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(14)),
                                  ),
                                  labelText: AppLocalizations.of(context)!.amount,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BlocBuilder<ItemEditCubit, ItemEditState>(
                              bloc: cubit,
                              buildWhen: (prev, curr) => prev.unit != curr.unit,
                              builder: (context, state) => DropdownButton<String?>(
                                value: state.unit,
                                hint: Text(AppLocalizations.of(context)!.unit),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(AppLocalizations.of(context)!.none),
                                  ),
                                  for (final u in kUnitOptions)
                                    DropdownMenuItem(value: u, child: Text(u)),
                                ],
                                onChanged: cubit.setUnit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  BlocBuilder<ItemEditCubit, ItemEditState>(
                    bloc: cubit,
                    buildWhen: (prev, curr) =>
                        prev.description != curr.description,
                    builder: (context, state) => (widget.item
                                is ItemWithDescription &&
                            ItemDescriptionParser.getSuggestions(
                                    state.description)
                                .isNotEmpty)
                        ? SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverToBoxAdapter(
                              child: Wrap(
                                  alignment: WrapAlignment.start,
                                  runSpacing: 8,
                                  spacing: 8,
                                  children:
                                      ItemDescriptionParser.getSuggestions(
                                              state.description)
                                          .map(
                                            (s) => ActionChip(
                                              label: Text(s.$1),
                                              onPressed: () {
                                                cubit.setDescription(s.$2);
                                                descController.text = s.$2;
                                              },
                                            ),
                                          )
                                          .toList()),
                            ),
                          )
                        : SliverToBoxAdapter(),
                  ),
                  if (widget.item is! RecipeItem)
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: (widget.item is ItemWithDescription) ? 8 : 16,
                        bottom: (widget.advancedView) ? 8 : 16,
                        left: 16,
                        right: 16,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            Text(
                              AppLocalizations.of(context)!.category,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      BlocBuilder<ItemEditCubit, ItemEditState>(
                                    bloc: cubit,
                                    buildWhen: (prev, curr) =>
                                        prev.category != curr.category,
                                    builder: (context, state) =>
                                        DropdownButton<Category?>(
                                      value: state.category,
                                      isExpanded: true,
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                            AppLocalizations.of(context)!.none,
                                          ),
                                        ),
                                        for (final e in widget.categories)
                                          DropdownMenuItem(
                                            value: e,
                                            child: Text(e.name),
                                          ),
                                      ],
                                      onChanged: !App.isOffline
                                          ? cubit.setCategory
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.item is ShoppinglistItem)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  AppLocalizations.of(context)!.addedBy(context
                                          .read<HouseholdCubit>()
                                          .state
                                          .household
                                          .member
                                          ?.firstWhereOrNull(
                                            (e) =>
                                                e.id ==
                                                (widget.item
                                                        as ShoppinglistItem)
                                                    .createdById,
                                          )
                                          ?.name ??
                                      AppLocalizations.of(context)!.other),
                                ),
                                trailing: (widget.item as ShoppinglistItem)
                                            .createdAt !=
                                        null
                                    ? Text(
                                        DateFormat.yMMMEd().add_jm().format(
                                              (widget.item as ShoppinglistItem)
                                                  .createdAt!,
                                            ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.item is! RecipeItem)
                    BlocBuilder<ItemEditCubit, ItemEditState>(
                      bloc: cubit,
                      buildWhen: (prev, curr) =>
                          prev.prices != curr.prices ||
                          prev.stores != curr.stores,
                      builder: (context, state) {
                        final household =
                            context.read<HouseholdCubit>().state.household;
                        if (!(household.featurePricing ?? false)) {
                          return const SliverToBoxAdapter();
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                if (i == 0) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Text(
                                            '${AppLocalizations.of(context)!.prices}:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                        ),
                                      ),
                                      if (state.stores.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          tooltip: AppLocalizations.of(context)!
                                              .priceAdd,
                                          onPressed: () async {
                                            final price =
                                                await showDialog<ItemPrice>(
                                              context: context,
                                              builder: (context) =>
                                                  ItemPriceDialog(
                                                stores: state.stores,
                                              ),
                                            );
                                            if (price != null) {
                                              cubit.addOrUpdateItemPrice(price);
                                            }
                                          },
                                        ),
                                    ],
                                  );
                                }
                                final price = state.prices[i - 1];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(price.store.name),
                                  subtitle: Text(
                                    '${AppLocalizations.of(context)!.packSize}: ${price.packAmount} ${price.packUnit}'
                                    '${price.soldLoose ? " (${AppLocalizations.of(context)!.soldLoose})" : ""}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        NumberFormat.simpleCurrency(
                                          locale: household.language,
                                        ).format(price.price),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_rounded),
                                        onPressed: () =>
                                            cubit.deleteItemPrice(price.store),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final updated =
                                        await showDialog<ItemPrice>(
                                      context: context,
                                      builder: (context) => ItemPriceDialog(
                                        stores: state.stores,
                                        initial: price,
                                      ),
                                    );
                                    if (updated != null) {
                                      cubit.addOrUpdateItemPrice(updated);
                                    }
                                  },
                                );
                              },
                              childCount: state.prices.length + 1,
                            ),
                          ),
                        );
                      },
                    ),
                  if (widget.advancedView)
                    BlocBuilder<ItemEditCubit, ItemEditState>(
                      bloc: cubit,
                      builder: (context, state) => SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (!App.isOffline)
                              ItemWrapMenu(
                                item: cubit.item,
                                household: context
                                    .read<HouseholdCubit>()
                                    .state
                                    .household,
                                setIcon: cubit.setIcon,
                                setName: cubit.setName,
                                mergeItem: cubit.mergeItem,
                                deleteItem: () async {
                                  await cubit.deleteItem();
                                  if (!mounted) return;
                                  Navigator.of(context).pop(
                                      const UpdateValue<Item>(
                                          UpdateEnum.deleted));
                                },
                              ),
                            const Divider(height: 32),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                AppLocalizations.of(context)!.about,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title:
                                  Text(AppLocalizations.of(context)!.ordering),
                              trailing: Text(widget.item.ordering.toString()),
                            ),
                            if (state.icon != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(AppLocalizations.of(context)!.icon),
                                trailing: Text(state.icon ?? ""),
                              ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  AppLocalizations.of(context)!.defaultWord),
                              trailing: Text(widget.item.isDefault.toString()),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  AppLocalizations.of(context)!.defaultKey),
                              trailing: Text(widget.item.defaultKey ?? ""),
                            ),
                            const Divider(),
                          ]),
                        ),
                      ),
                    ),
                  if (widget.item is! RecipeItem &&
                      context.readOrNull<HouseholdCubit>() != null)
                    BlocBuilder<ItemEditCubit, ItemEditState>(
                      bloc: cubit,
                      builder: (context, state) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                if (i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${AppLocalizations.of(context)!.usedIn}:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  );
                                }
                                i = i - 1;

                                return RecipeItemWidget(
                                  recipe: state.recipes[i],
                                  onUpdated: cubit.refresh,
                                  description: state.recipes[i].isPlanned &&
                                          state.recipes[i].items.isNotEmpty &&
                                          state.recipes[i].items.first
                                              .description.isNotEmpty
                                      ? Text(
                                          "${state.recipes[i].items.first.description}${state.recipes[i].items.first.optional ? " (${AppLocalizations.of(context)!.optional})" : ""}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        )
                                      : state.recipes[i].items.first.optional
                                          ? Text(
                                              AppLocalizations.of(context)!
                                                  .optional,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            )
                                          : null,
                                );
                              },
                              childCount: state.recipes.isEmpty
                                  ? 0
                                  : state.recipes.length + 1,
                            ),
                          ),
                        );
                      },
                    ),
                  SliverToBoxAdapter(
                    child:
                        SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
