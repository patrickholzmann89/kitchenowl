import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/aldi_search_cubit.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/aldi_article.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/item_price.dart';
import 'package:kitchenowl/widgets/aldi_article_confirm_dialog.dart';

class AldiSearchPage extends StatefulWidget {
  final Household household;
  final Item item;

  const AldiSearchPage({
    super.key,
    required this.household,
    required this.item,
  });

  @override
  State<AldiSearchPage> createState() => _AldiSearchPageState();
}

class _AldiSearchPageState extends State<AldiSearchPage> {
  late final TextEditingController searchController;
  late AldiSearchCubit cubit;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.item.name);
    cubit = AldiSearchCubit(widget.household, widget.item);
  }

  @override
  void dispose() {
    cubit.close();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _selectArticle(AldiArticle article) async {
    final confirmed = await showDialog<AldiArticle>(
      context: context,
      builder: (context) => AldiArticleConfirmDialog(article: article),
    );
    if (confirmed == null) return;

    final store = await cubit.resolveAldiStore();
    if (store == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.aldiSearchError)),
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
      ),
      confirmed.pieceWeight,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.aldiSearch),
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
              child: BlocBuilder<AldiSearchCubit, AldiSearchState>(
                bloc: cubit,
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.hasError) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.aldiSearchError,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (state.results.isEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.aldiSearchNoResults,
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
