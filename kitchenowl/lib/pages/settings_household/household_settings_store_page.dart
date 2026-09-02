import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_add_update/household_update_cubit.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/widgets/dismissible_card.dart';
import 'package:kitchenowl/widgets/store_circle_avatar.dart';
import 'package:kitchenowl/widgets/store_edit_dialog.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HouseholdSettingsStorePage extends StatelessWidget {
  const HouseholdSettingsStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(AppLocalizations.of(context)!.stores),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.storeAdd,
                onPressed: () async {
                  final res = await showDialog<StoreEditResult>(
                    context: context,
                    builder: (BuildContext context) {
                      return StoreEditDialog(
                        title: AppLocalizations.of(context)!.storeAdd,
                        doneText: AppLocalizations.of(context)!.add,
                      );
                    },
                  );
                  if (res != null && context.mounted) {
                    BlocProvider.of<HouseholdUpdateCubit>(context)
                        .addStore(res.name, res.photo);
                  }
                },
              ),
            ],
          ),
          SliverCrossAxisConstrained(
            maxCrossAxisExtent: 600,
            child: BlocBuilder<HouseholdUpdateCubit, HouseholdUpdateState>(
              buildWhen: (prev, curr) =>
                  prev.stores != curr.stores ||
                  prev is LoadingHouseholdUpdateState,
              builder: (context, state) {
                if (state is LoadingHouseholdUpdateState) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    childCount: state.stores.length,
                    (context, i) => DismissibleCard(
                      key: ValueKey<Store>(state.stores.elementAt(i)),
                      confirmDismiss: (direction) async {
                        return (await askForConfirmation(
                          context: context,
                          title: Text(
                            AppLocalizations.of(context)!.storeDelete,
                          ),
                          content: Text(
                            AppLocalizations.of(context)!
                                .storeDeleteConfirmation(
                              state.stores.elementAt(i).name,
                            ),
                          ),
                        ));
                      },
                      onDismissed: (direction) {
                        BlocProvider.of<HouseholdUpdateCubit>(context)
                            .deleteStore(state.stores.elementAt(i));
                      },
                      leading: StoreCircleAvatar(
                        store: state.stores.elementAt(i),
                      ),
                      title: Text(state.stores.elementAt(i).name),
                      onTap: () async {
                        final store = state.stores.elementAt(i);
                        final res = await showDialog<StoreEditResult>(
                          context: context,
                          builder: (BuildContext context) {
                            return StoreEditDialog(
                              title: AppLocalizations.of(context)!.rename,
                              doneText: AppLocalizations.of(context)!.rename,
                              initialName: store.name,
                              initialPhoto: store.photo,
                            );
                          },
                        );
                        if (res != null && context.mounted) {
                          BlocProvider.of<HouseholdUpdateCubit>(context)
                              .updateStore(
                            store.copyWith(name: res.name, photo: res.photo),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
