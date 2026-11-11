import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/services/catalog_service.dart';

import 'mock_repository.dart';

/// The Series Jeen catalog from the saved snapshot in mock_catalog_data.dart,
/// paged like the backend. Episodes play the clips bundled with the app.
class MockCatalogService implements CatalogService {
  MockCatalogService(this._repository);

  final MockRepository _repository;

  static const platformId = 19;
  static const _pageSize = 20;

  @override
  Future<List<CatalogPlatform>> platforms() async => [
    CatalogPlatform(
      id: platformId,
      name: 'FreeReels',
      dramaCount: _repository.catalogDramas.length,
      hasAccess: true,
    ),
  ];

  @override
  Future<CatalogPage> dramas(
    int platformId, {
    String? query,
    int page = 1,
  }) async {
    final text = (query ?? '').trim().toLowerCase();
    final all = [
      for (final d in _repository.catalogDramas)
        if (text.isEmpty || d.title.toLowerCase().contains(text)) d,
    ];
    final pages = (all.length / _pageSize).ceil();
    final start = (page - 1) * _pageSize;
    return CatalogPage(
      items: all.skip(start).take(_pageSize).toList(),
      page: page,
      totalPages: pages == 0 ? 1 : pages,
    );
  }

  @override
  Future<List<EpisodePart>> episodeParts(int dramaId, int episode) async => [
    EpisodePart.fromJson({'url': 'asset:${MockRepository.clipFor(episode)}'}),
  ];

  /// The bundled clips have no subtitles.
  @override
  Future<String?> fetchSubtitle(String url) async => null;
}
