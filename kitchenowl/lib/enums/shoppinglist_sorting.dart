import 'package:kitchenowl/models/item.dart';

enum ShoppinglistSorting {
  alphabetical,
  algorithmic,
  category,
  store;

  static void sortShoppinglistItems(
    List<Item> shoppinglist,
    ShoppinglistSorting sorting,
  ) {
    if (shoppinglist.isEmpty) return;
    switch (sorting) {
      case ShoppinglistSorting.alphabetical:
      case ShoppinglistSorting.category:
      case ShoppinglistSorting.store:
        shoppinglist.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ShoppinglistSorting.algorithmic:
        shoppinglist.sort((a, b) {
          final int ordering = a.ordering.compareTo(b.ordering);
          // Ordering of 0 means not sortable and should be at the back
          if (ordering != 0 && a.ordering == 0) return 1;
          if (ordering != 0 && b.ordering == 0) return -1;

          return ordering;
        });
        break;
    }
  }
}
