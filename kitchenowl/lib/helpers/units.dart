/// Unit vocabulary mirroring the backend's `app.util.units.ALLOWED_UNITS` -
/// used for structured recipe/shoppinglist item amounts and item price pack
/// sizes so both sides can be compared/summed.
const List<String> kUnitOptions = [
  "piece",
  "mg",
  "g",
  "kg",
  "tsp",
  "tbsp",
  "ml",
  "l",
];

/// Formats a structured amount for display, e.g. "250" or "1.5" - trims a
/// trailing ".0" so whole numbers don't look like "250.0".
String formatAmount(double amount) => amount.truncateToDouble() == amount
    ? amount.truncate().toString()
    : amount.toString();
