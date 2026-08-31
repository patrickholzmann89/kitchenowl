import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/receipt_scraper_cubit.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/widgets/receipt_line_tile.dart';

class ReceiptScraperPage extends StatefulWidget {
  final NamedByteArray file;
  final Household household;

  const ReceiptScraperPage({
    super.key,
    required this.file,
    required this.household,
  });

  @override
  State<ReceiptScraperPage> createState() => _ReceiptScraperPageState();
}

class _ReceiptScraperPageState extends State<ReceiptScraperPage> {
  late ReceiptScraperCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = ReceiptScraperCubit(widget.household, widget.file);
  }

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.receiptScan),
        ),
        body: BlocBuilder<ReceiptScraperCubit, ReceiptScraperState>(
          bloc: cubit,
          builder: (context, state) {
            if (state is ReceiptScraperUnsupportedState ||
                state is ReceiptScraperErrorState) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    AppLocalizations.of(context)!.receiptScanUnsupportedMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            if (state is! ReceiptScraperLoadedState) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizations.of(context)!.receiptScanAnalysing,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: DropdownButtonFormField<Store>(
                    initialValue: state.selectedStore,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.storeAdd,
                    ),
                    items: state.stores
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (s) {
                      if (s != null) cubit.updateStore(s);
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.lines.length,
                    itemBuilder: (context, index) => ReceiptLineTile(
                      household: widget.household,
                      line: state.lines[index],
                      selectedStore: state.selectedStore,
                      excluded: state.excludedIndices.contains(index),
                      onItemSelected: (item) => cubit.updateItem(index, item),
                      onPriceChanged: (price) =>
                          cubit.updatePrice(index, price),
                      onToggleExcluded: () => cubit.toggleExcluded(index),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isValid
                          ? () async {
                              final (updated, attempted) =
                                  await cubit.confirm();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context)!
                                          .receiptScanImportResult(
                                        updated,
                                        attempted,
                                      ),
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                      child: Text(
                        AppLocalizations.of(context)!.receiptScanConfirm,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
