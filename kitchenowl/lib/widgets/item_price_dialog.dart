import 'package:flutter/material.dart';
import 'package:kitchenowl/helpers/units.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/models/store.dart';

class ItemPriceDialog extends StatefulWidget {
  final List<Store> stores;
  final ItemPrice? initial;

  const ItemPriceDialog({
    super.key,
    required this.stores,
    this.initial,
  });

  @override
  State<ItemPriceDialog> createState() => _ItemPriceDialogState();
}

class _ItemPriceDialogState extends State<ItemPriceDialog> {
  late Store? store;
  late final TextEditingController priceController;
  late final TextEditingController packAmountController;
  late String packUnit;
  late bool soldLoose;

  @override
  void initState() {
    super.initState();
    store = widget.initial?.store ??
        (widget.stores.length == 1 ? widget.stores.first : null);
    priceController = TextEditingController(
      text: widget.initial?.price.toString() ?? '',
    );
    packAmountController = TextEditingController(
      text: widget.initial?.packAmount.toString() ?? '1',
    );
    packUnit = widget.initial?.packUnit ?? kUnitOptions.first;
    soldLoose = widget.initial?.soldLoose ?? false;
  }

  @override
  void dispose() {
    priceController.dispose();
    packAmountController.dispose();
    super.dispose();
  }

  bool get isValid =>
      store != null &&
      double.tryParse(priceController.text.replaceAll(',', '.')) != null &&
      (double.tryParse(packAmountController.text.replaceAll(',', '.')) ?? 0) >
          0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        widget.initial == null
            ? AppLocalizations.of(context)!.priceAdd
            : AppLocalizations.of(context)!.priceEdit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Store>(
              initialValue: store,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.storeAdd,
              ),
              items: widget.stores
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: widget.initial == null
                  ? (s) => setState(() => store = s)
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.pricePerPack,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: packAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.packSize,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: packUnit,
                  items: [
                    for (final u in kUnitOptions)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (u) => setState(() => packUnit = u ?? packUnit),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(AppLocalizations.of(context)!.soldLoose),
              subtitle: Text(AppLocalizations.of(context)!.soldLooseHint),
              value: soldLoose,
              onChanged: (v) => setState(() => soldLoose = v ?? soldLoose),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: isValid
              ? () => Navigator.of(context).pop(ItemPrice(
                    itemId: widget.initial?.itemId ?? 0,
                    store: store!,
                    price: double.parse(
                      priceController.text.replaceAll(',', '.'),
                    ),
                    packAmount: double.parse(
                      packAmountController.text.replaceAll(',', '.'),
                    ),
                    packUnit: packUnit,
                    soldLoose: soldLoose,
                    externalRef: widget.initial?.externalRef,
                  ))
              : null,
          child: Text(AppLocalizations.of(context)!.set),
        ),
      ],
    );
  }
}
