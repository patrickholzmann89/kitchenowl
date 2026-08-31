import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_add_update/household_update_cubit.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/store.dart';
import 'package:kitchenowl/widgets/dismissible_card.dart';
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
                  final res = await showDialog<String>(
                    context: context,
                    builder: (BuildContext context) {
                      return TextDialog(
                        title: AppLocalizations.of(context)!.storeAdd,
                        doneText: AppLocalizations.of(context)!.add,
                        hintText: AppLocalizations.of(context)!.name,
                        isInputValid: (s) => s.trim().isNotEmpty,
                      );
                    },
                  );
                  if (res != null) {
                    BlocProvider.of<HouseholdUpdateCubit>(context)
                        .addStore(res);
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
                      title: Text(state.stores.elementAt(i).name),
                      onTap: () async {
                        final res = await showDialog<String>(
                          context: context,
                          builder: (BuildContext context) {
                            return TextDialog(
                              title: AppLocalizations.of(context)!.rename,
                              doneText: AppLocalizations.of(context)!.rename,
                              hintText: AppLocalizations.of(context)!.name,
                              initialText: state.stores.elementAt(i).name,
                              isInputValid: (s) =>
                                  s.trim().isNotEmpty &&
                                  s != state.stores.elementAt(i).name,
                            );
                          },
                        );
                        if (res != null) {
                          BlocProvider.of<HouseholdUpdateCubit>(context)
                              .updateStore(
                            state.stores.elementAt(i).copyWith(name: res),
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
