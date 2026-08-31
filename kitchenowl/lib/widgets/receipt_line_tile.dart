import 'package:flutter/material.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/models/receipt_scrape.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/pages/item_search_page.dart';
import 'package:kitchenowl/widgets/item_price_dialog.dart';

class ReceiptLineTile extends StatelessWidget {
  final Household household;
  final ReceiptLineItem line;
  final Store? selectedStore;
  final bool excluded;
  final void Function(Item?) onItemSelected;
  final void Function(ItemPrice) onPriceChanged;
  final VoidCallback onToggleExcluded;

  const ReceiptLineTile({
    super.key,
    required this.household,
    required this.line,
    required this.selectedStore,
    required this.excluded,
    required this.onItemSelected,
    required this.onPriceChanged,
    required this.onToggleExcluded,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: excluded ? 0.5 : 1,
      child: ListTile(
        title: Text(line.item?.name ?? line.rawText),
        subtitle: Text(
          line.pieceWeight != null
              ? '${line.rawText}\n${AppLocalizations.of(context)!.receiptScanPieceWeightDetected(line.pieceWeight!.toStringAsFixed(0))}'
              : line.rawText,
        ),
        isThreeLine: line.pieceWeight != null,
        onTap: () => _selectItem(context),
        leading: IconButton(
          icon: Icon(excluded ? Icons.add_circle_outline : Icons.close),
          tooltip: excluded
              ? AppLocalizations.of(context)!.add
              : AppLocalizations.of(context)!.remove,
          onPressed: onToggleExcluded,
        ),
        trailing: TextButton(
          onPressed: selectedStore == null ? null : () => _editPrice(context),
          child: Text(line.price.toStringAsFixed(2)),
        ),
      ),
    );
  }

  Future<void> _selectItem(BuildContext context) async {
    final items = await Navigator.of(context, rootNavigator: true)
            .push<List<Item>>(MaterialPageRoute(
          builder: (context) => ItemSearchPage(
            household: household,
            multiple: false,
            title: line.rawText,
            selectedItems: line.item != null ? [line.item!] : const [],
          ),
        )) ??
        [];
    if (items.length == 1) {
      onItemSelected(items[0]);
    }
  }

  Future<void> _editPrice(BuildContext context) async {
    final result = await showDialog<ItemPrice>(
      context: context,
      builder: (context) => ItemPriceDialog(
        stores: [selectedStore!],
        initial: ItemPrice(
          itemId: line.item?.id ?? 0,
          store: selectedStore!,
          price: line.price,
        ),
      ),
    );
    if (result != null) {
      onPriceChanged(result);
    }
  }
}
