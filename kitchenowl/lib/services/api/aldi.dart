import 'dart:convert';

import 'package:kitchenowl/models/aldi_article.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension AldiApi on ApiService {
  Future<List<AldiArticle>?> searchAldiArticles(Item item, String query) async {
    final res = await get(
      '/item/${item.id}/aldi-search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (res.statusCode != 200) return null;

    return List<AldiArticle>.from(
      jsonDecode(res.body).map((e) => AldiArticle.fromJson(e)),
    );
  }
}
