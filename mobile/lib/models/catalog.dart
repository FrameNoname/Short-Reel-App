/// Series from the Series Jeen catalog, as our backend relays them.
class CatalogPlatform {
  const CatalogPlatform({
    required this.id,
    required this.name,
    required this.dramaCount,
    required this.hasAccess,
  });

  final int id;
  final String name;
  final int dramaCount;
  final bool hasAccess;

  factory CatalogPlatform.fromJson(Map<String, dynamic> json) =>
      CatalogPlatform(
        id: json['id'] as int,
        name: json['name'] as String,
        dramaCount: json['drama_count'] as int? ?? 0,
        hasAccess: json['has_access'] == true,
      );
}

class CatalogDrama {
  const CatalogDrama({
    required this.id,
    required this.title,
    required this.description,
    required this.episodeCount,
    required this.genres,
    required this.posterUrl,
    required this.thaiDub,
    required this.thaiSub,
  });

  final int id;
  final String title;
  final String? description;
  final int episodeCount;
  final List<String> genres;
  final String? posterUrl;
  final bool thaiDub;
  final bool thaiSub;

  factory CatalogDrama.fromJson(Map<String, dynamic> json) => CatalogDrama(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    episodeCount: json['episode_count'] as int? ?? 0,
    genres: [for (final g in json['genres'] as List? ?? const []) g as String],
    posterUrl: json['poster'] as String?,
    thaiDub: json['thai_dub'] == true,
    thaiSub: json['thai_sub'] == true,
  );
}

class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<CatalogDrama> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory CatalogPage.fromJson(Map<String, dynamic> json) => CatalogPage(
    items: [
      for (final i in json['items'] as List)
        CatalogDrama.fromJson(i as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    totalPages: json['total_pages'] as int,
  );
}

/// One playable piece of an episode. An episode with several parts plays them
/// back to back.
class EpisodePart {
  const EpisodePart({required this.url, this.thaiSubtitleUrl});

  final String url;
  final String? thaiSubtitleUrl;

  factory EpisodePart.fromJson(Map<String, dynamic> json) {
    final subtitles = json['subtitles'] as List? ?? const [];
    String? thai;
    for (final s in subtitles.cast<Map<String, dynamic>>()) {
      if (s['language'] == 'th' && s['forced'] != true && thai == null) {
        thai = s['url'] as String?;
      }
    }
    return EpisodePart(url: json['url'] as String, thaiSubtitleUrl: thai);
  }
}

/// The parts of the first episode in an episode-links reply.
List<EpisodePart> episodePartsFromJson(Map<String, dynamic> json) {
  final episodes = json['episodes'] as List;
  if (episodes.isEmpty) return const [];
  final parts = (episodes.first as Map<String, dynamic>)['parts'] as List;
  return [
    for (final p in parts) EpisodePart.fromJson(p as Map<String, dynamic>),
  ];
}
