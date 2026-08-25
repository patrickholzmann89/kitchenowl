import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/cubits/settings_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/update_value.dart';
import 'package:kitchenowl/pages/item_page.dart';
import 'package:kitchenowl/pages/item_search_page.dart';
import 'package:kitchenowl/widgets/shopping_item.dart';

class StringItemMatch extends StatelessWidget {
  final Household household;
  final String string;
  final RecipeItem? item;
  final void Function(RecipeItem?) itemSelected;
  final bool optional;

  StringItemMatch({
    super.key,
    required this.household,
    required this.itemSelected,
    required this.string,
    this.item,
  }) : optional = item?.optional ?? false;

  // `item` is set as soon as a recipe/pdf/text scrape parses a
  // amount/unit/description for this ingredient, even before it's linked to
  // an actual household item (see recipe_scraping.py) - only a real `id`
  // means it's linked to one and can be shown/edited as such.
  bool get _isLinked => item?.id != null;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1 /
          DynamicStyling.itemCrossAxisCount(
            MediaQuery.sizeOf(context).width - 32,
            context.read<SettingsCubit>().state.gridSize,
          ),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: ListTile(
              title: Text(
                string,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              contentPadding: const EdgeInsets.only(left: 0, right: 0),
              horizontalTitleGap: 0,
              trailing: _isLinked
                  ? IconButton(
                      onPressed: () => itemSelected(null),
                      tooltip: AppLocalizations.of(context)!.remove,
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AspectRatio(
              aspectRatio: 1,
              child: _isLinked
                  ? ShoppingItemWidget(
                      item: item!,
                      selected: true,
                      onPressed: (_) => _onPressed(context),
                      onLongPressed: (_) => _onLongPressed(context),
                    )
                  : Center(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: OutlinedButton(
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(EdgeInsets.zero),
                          ),
                          onPressed: () => _onPressed(context),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
            ),
          ),
          if (_isLinked)
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context)!.optional),
                ),
                KitchenOwlSwitch(
                  value: optional,
                  onChanged: _setOptional,
                ),
              ],
            ),
          if (!_isLinked) const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    final items = await Navigator.of(context, rootNavigator: true)
            .push<List<Item>>(MaterialPageRoute(
          builder: (context) => ItemSearchPage(
            household: household,
            multiple: false,
            title: string,
            selectedItems: _isLinked ? [item!] : const [],
          ),
        )) ??
        [];
    if (items.length == 1) {
      itemSelected(
        RecipeItem.fromItem(
          item: items[0],
          description: item?.description ?? '',
          amount: item?.amount,
          unit: item?.unit,
          optional: optional,
        ),
      );
    }
  }

  Future<void> _onLongPressed(BuildContext context) async {
    final res = await Navigator.of(context, rootNavigator: true)
        .push<UpdateValue<RecipeItem>>(
      MaterialPageRoute(
        builder: (BuildContext ctx) => BlocProvider.value(
          value: context.read<HouseholdCubit>(),
          child: ItemPage(
            item: item!,
          ),
        ),
      ),
    );
    if (res != null &&
        res.data != null &&
        (res.state == UpdateEnum.deleted || res.state == UpdateEnum.updated)) {
      itemSelected(res.data!);
    }
  }

  void _setOptional(bool value) {
    itemSelected(item!.copyWith(optional: value));
  }
}
