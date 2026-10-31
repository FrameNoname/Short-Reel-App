enum LengthFilter { any, under5, from5to15, from15to30 }

class FilmFilter {
  const FilmFilter({
    this.query = '',
    this.genres = const {},
    this.length = LengthFilter.any,
    this.aiTools = const {},
  });

  final String query;
  final Set<String> genres;
  final LengthFilter length;
  final Set<String> aiTools;

  bool get hasFilters =>
      genres.isNotEmpty || length != LengthFilter.any || aiTools.isNotEmpty;

  FilmFilter copyWith({
    String? query,
    Set<String>? genres,
    LengthFilter? length,
    Set<String>? aiTools,
  }) {
    return FilmFilter(
      query: query ?? this.query,
      genres: genres ?? this.genres,
      length: length ?? this.length,
      aiTools: aiTools ?? this.aiTools,
    );
  }
}
