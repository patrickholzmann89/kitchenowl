import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/services/api/pricing.dart';

class CostEstimateBanner extends StatelessWidget {
  final CostEstimate costEstimate;
  final String? locale;

  const CostEstimateBanner({
    super.key,
    required this.costEstimate,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    if (costEstimate.total == null) return const SizedBox.shrink();

    final currency = NumberFormat.simpleCurrency(locale: locale);
    // Only worth breaking down when the items actually came from more than
    // one store - otherwise it'd just repeat the total.
    final showBreakdown = costEstimate.byStore.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: ElevationOverlay.applySurfaceTint(
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.surfaceTint,
          1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.estimatedCost,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Text(
                    "${currency.format(costEstimate.total!)}"
                    "${!costEstimate.complete ? " (${AppLocalizations.of(context)!.approximately})" : ""}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              if (showBreakdown) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                ...costEstimate.byStore.map(
                  (store) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            store.storeName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currency.format(store.total),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
