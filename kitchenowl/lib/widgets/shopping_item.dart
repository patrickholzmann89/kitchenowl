import 'package:flutter/material.dart';
import 'package:kitchenowl/helpers/units.dart';
import 'package:kitchenowl/item_icons.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/styles/dynamic.dart';
import 'package:kitchenowl/widgets/image_provider.dart';
import 'package:kitchenowl/widgets/selectable_button_card.dart';
import 'package:kitchenowl/widgets/selectable_button_list_tile.dart';

/// Combines the structured amount/unit with the free-text description into
/// a single display line, e.g. "250 ml", "2 Zehen" (unit "piece" - the noun
/// carries the meaning instead), or just "gewürfelt" when there's no amount.
String? _formatItemDescription(ItemWithDescription item) {
  final parts = <String>[];
  if (item.amount != null) {
    final amountText = formatAmount(item.amount!);
    parts.add(
      item.unit != null && item.unit != 'piece'
          ? '$amountText ${item.unit}'
          : amountText,
    );
  }
  if (item.description.isNotEmpty) parts.add(item.description);

  return parts.isEmpty ? null : parts.join(' ');
}

class ShoppingItemWidget<T extends Item> extends StatelessWidget {
  final T item;
  final void Function(T)? onPressed;
  final void Function(T)? onLongPressed;
  final bool selected;
  final Widget? extraOption;

  /// Only applicable if gridStyle = false, raises the list items and makes them fully opaque.
  /// defaults to true for item is ShoppinglistItem || item is RecipeItem && selected
  final bool? raised;
  final bool gridStyle;
  final ListStyle listStyle;
  final bool showPhoto;

  const ShoppingItemWidget({
    super.key,
    required this.item,
    this.onPressed,
    this.onLongPressed,
    this.selected = false,
    this.gridStyle = true,
    this.listStyle = ListStyle.cards,
    this.raised,
    this.extraOption,
    this.showPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = (showPhoto && item.photo != null)
        ? getImageProvider(context, item.photo!)
        : null;
    final description = (item is ItemWithDescription)
        ? _formatItemDescription(item as ItemWithDescription)
        : null;

    return gridStyle
        ? SelectableButtonCard(
            title: item.name,
            selected: selected,
            icon: ItemIcons.get(item),
            image: image,
            description: description,
            onPressed: onPressed != null ? () => onPressed!(item) : null,
            onLongPressed:
                onLongPressed != null ? () => onLongPressed!(item) : null,
            extraOption: extraOption,
          )
        : SelectableButtonListTile(
            title: item.name,
            selected: selected,
            icon: ItemIcons.get(item),
            image: image,
            listStyle: listStyle,
            raised: raised ??
                item is ShoppinglistItem || item is RecipeItem && selected,
            description: description,
            onPressed: onPressed != null ? () => onPressed!(item) : null,
            onLongPressed:
                onLongPressed != null ? () => onLongPressed!(item) : null,
            extraOption: extraOption,
          );
  }
}
