import 'dart:convert';

import 'package:kitchenowl/models/dm_article.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension DmApi on ApiService {
  Future<List<DmArticle>?> searchDmArticles(Item item, String query) async {
    final res = await get(
      '/item/${item.id}/dm-search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (res.statusCode != 200) return null;

    return List<DmArticle>.from(
      jsonDecode(res.body).map((e) => DmArticle.fromJson(e)),
    );
  }
}
