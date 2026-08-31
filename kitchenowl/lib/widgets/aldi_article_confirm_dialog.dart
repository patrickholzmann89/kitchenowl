import 'package:flutter/material.dart';
import 'package:kitchenowl/helpers/units.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/aldi_article.dart';

class AldiArticleConfirmDialog extends StatefulWidget {
  final AldiArticle article;

  const AldiArticleConfirmDialog({super.key, required this.article});

  @override
  State<AldiArticleConfirmDialog> createState() =>
      _AldiArticleConfirmDialogState();
}

class _AldiArticleConfirmDialogState extends State<AldiArticleConfirmDialog> {
  late final TextEditingController priceController;
  late final TextEditingController packAmountController;
  late final TextEditingController pieceWeightController;
  late String packUnit;

  @override
  void initState() {
    super.initState();
    priceController = TextEditingController(
      text: widget.article.price.toString(),
    );
    packAmountController = TextEditingController(
      text: widget.article.packAmount.toString(),
    );
    pieceWeightController = TextEditingController(
      text: widget.article.pieceWeight?.toString() ?? '',
    );
    packUnit = widget.article.packUnit;
  }

  @override
  void dispose() {
    priceController.dispose();
    packAmountController.dispose();
    pieceWeightController.dispose();
    super.dispose();
  }

  bool get isValid =>
      double.tryParse(priceController.text.replaceAll(',', '.')) != null &&
      (double.tryParse(packAmountController.text.replaceAll(',', '.')) ?? 0) >
          0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 12),
            TextField(
              controller: pieceWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.pieceWeight,
                helperText: AppLocalizations.of(context)!.pieceWeightHint,
                helperMaxLines: 3,
              ),
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
              ? () => Navigator.of(context).pop(widget.article.copyWith(
                    price: double.parse(
                      priceController.text.replaceAll(',', '.'),
                    ),
                    packAmount: double.parse(
                      packAmountController.text.replaceAll(',', '.'),
                    ),
                    packUnit: packUnit,
                    pieceWeight: () => double.tryParse(
                      pieceWeightController.text.replaceAll(',', '.'),
                    ),
                  ))
              : null,
          child: Text(AppLocalizations.of(context)!.set),
        ),
      ],
    );
  }
}
