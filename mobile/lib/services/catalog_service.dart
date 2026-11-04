import 'package:dio/dio.dart';

import '../models/catalog.dart';
import 'api_client.dart';

/// Reads the Series Jeen catalog through our own backend, which holds the
/// provider key. The app never sees that key.
class CatalogService {
  CatalogService(this._api, {Dio? subtitleClient})
    : _subtitles = subtitleClient ?? Dio();

  final ApiClient _api;

  // Subtitle files are public, so they are fetched without our login token.
  final Dio _subtitles;

  Future<List<CatalogPlatform>> platforms() async {
    final json = await _api.get('/catalog/platforms') as Map<String, dynamic>;
    return [
      for (final p in json['items'] as List)
        CatalogPlatform.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<CatalogPage> dramas(
    int platformId, {
    String? query,
    int page = 1,
  }) async {
    final json =
        await _api.get(
              '/catalog/platforms/$platformId/dramas',
              query: {
                'page': page,
                'page_size': 20,
                if (query != null && query.isNotEmpty) 'q': query,
              },
            )
            as Map<String, dynamic>;
    return CatalogPage.fromJson(json);
  }

  /// Links for one episode. This spends the provider's quota, so call it only
  /// when the viewer presses play.
  Future<List<EpisodePart>> episodeParts(int dramaId, int episode) async {
    final json =
        await _api.get(
              '/catalog/dramas/$dramaId/episodes',
              query: {'ep': episode},
            )
            as Map<String, dynamic>;
    return episodePartsFromJson(json);
  }

  /// The text of a WebVTT subtitle file, or null when it cannot be fetched;
  /// the video then simply plays without subtitles.
  Future<String?> fetchSubtitle(String url) async {
    try {
      final response = await _subtitles.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data;
    } on DioException {
      return null;
    }
  }
}
