import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/dm_search_cubit.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/dm_article.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/widgets/dm_article_confirm_dialog.dart';

class DmSearchPage extends StatefulWidget {
  final Household household;
  final Item item;

  const DmSearchPage({
    super.key,
    required this.household,
    required this.item,
  });

  @override
  State<DmSearchPage> createState() => _DmSearchPageState();
}

class _DmSearchPageState extends State<DmSearchPage> {
  late final TextEditingController searchController;
  late DmSearchCubit cubit;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.item.name);
    cubit = DmSearchCubit(widget.household, widget.item);
  }

  @override
  void dispose() {
    cubit.close();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _selectArticle(DmArticle article) async {
    final confirmed = await showDialog<DmArticle>(
      context: context,
      builder: (context) => DmArticleConfirmDialog(article: article),
    );
    if (confirmed == null) return;

    final store = await cubit.resolveDmStore();
    if (store == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.dmSearchError)),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop((
      ItemPrice(
        itemId: widget.item.id ?? 0,
        store: store,
        price: confirmed.price,
        packAmount: confirmed.packAmount,
        packUnit: confirmed.packUnit,
        externalRef: confirmed.externalRef,
      ),
      confirmed.pieceWeight,
      confirmed.imageUrl,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.dmSearch),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: cubit.search,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  labelText: AppLocalizations.of(context)!.search,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => cubit.search(searchController.text),
                  ),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<DmSearchCubit, DmSearchState>(
                bloc: cubit,
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.hasError) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.dmSearchError,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (state.results.isEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.dmSearchNoResults,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: state.results.length,
                    itemBuilder: (context, index) {
                      final article = state.results[index];

                      return ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: article.imageUrl != null
                              ? Image.network(
                                  article.imageUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.shopping_bag_outlined),
                                )
                              : const Icon(Icons.shopping_bag_outlined),
                        ),
                        title: Text(article.title),
                        subtitle: Text(
                          '${article.packAmount} ${article.packUnit}',
                        ),
                        trailing: Text(
                          '${article.price.toStringAsFixed(2)} €',
                        ),
                        onTap: () => _selectArticle(article),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
