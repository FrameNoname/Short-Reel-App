class Film {
  const Film({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.genreId,
    required this.aiToolId,
    required this.promptCredit,
    required this.isAiGenerated,
    required this.status,
  });

  final int id;
  final int creatorId;
  final String title;
  final String? synopsis;
  final String? posterUrl;
  final int genreId;
  final int aiToolId;
  final String? promptCredit;
  final bool isAiGenerated;
  final String status;

  factory Film.fromJson(Map<String, dynamic> json) => Film(
        id: json['id'] as int,
        creatorId: json['creator_id'] as int,
        title: json['title'] as String,
        synopsis: json['synopsis'] as String?,
        posterUrl: json['poster_url'] as String?,
        genreId: json['genre_id'] as int,
        aiToolId: json['ai_tool_id'] as int,
        promptCredit: json['prompt_credit'] as String?,
        isAiGenerated: json['is_ai_generated'] == 1,
        status: json['status'] as String,
      );
}
