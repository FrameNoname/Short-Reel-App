import 'package:flutter/foundation.dart';

import '../models/catalog.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';

class CatalogController extends ChangeNotifier {
  CatalogController(this.service);

  final CatalogService service;

  List<CatalogPlatform> platforms = const [];
  CatalogPlatform? platform;
  List<CatalogDrama> dramas = const [];
  String query = '';
  bool isLoading = false;
  bool hasMore = false;
  String? error;

  int _page = 0;
  // A slow reply for an old search must not replace a newer one.
  int _request = 0;

  Future<void> load() async {
    if (platforms.isNotEmpty) return;
    await _run(() async {
      final all = await service.platforms();
      // Only platforms the account bought can list titles.
      platforms = all.where((p) => p.hasAccess).toList();
      platform = platforms.isEmpty ? null : platforms.first;
      if (platform != null) await _fetch(reset: true);
    });
  }

  Future<void> selectPlatform(CatalogPlatform value) async {
    platform = value;
    await _run(() => _fetch(reset: true));
  }

  Future<void> search(String value) async {
    query = value.trim();
    await _run(() => _fetch(reset: true));
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    await _run(() => _fetch(reset: false));
  }

  Future<void> _fetch({required bool reset}) async {
    final current = platform;
    if (current == null) return;
    final id = ++_request;
    final page = await service.dramas(
      current.id,
      query: query,
      page: reset ? 1 : _page + 1,
    );
    if (id != _request) return;
    _page = page.page;
    hasMore = page.hasMore;
    dramas = reset ? page.items : [...dramas, ...page.items];
  }

  Future<void> _run(Future<void> Function() body) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await body();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
