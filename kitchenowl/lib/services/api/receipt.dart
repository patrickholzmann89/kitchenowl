import 'dart:convert';

import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/receipt_scrape.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension ReceiptApi on ApiService {
  static const baseRoute = '/receipt';

  // ignore: constant_identifier_names
  static const Duration _TIMEOUT_SCRAPE = Duration(minutes: 3);

  Future<(ReceiptScrape?, int)> scrapeReceipt(
    Household household,
    NamedByteArray file,
  ) async {
    final res = await postBytes(
      '${householdPath(household)}$baseRoute/scrape',
      file,
      timeout: _TIMEOUT_SCRAPE,
    );
    if (res.statusCode != 200) return (null, res.statusCode);

    final body = jsonDecode(res.body);

    return (ReceiptScrape.fromJson(body), 200);
  }
}
