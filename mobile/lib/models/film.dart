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
    this.creatorName = '',
    this.genreName = '',
    this.aiToolName = '',
    this.reviewNote,
    this.likeCount = 0,
    this.commentCount = 0,
    this.episodeCount = 0,
    this.catalogDramaId,
    this.genreTags = const [],
    this.totalDurationSec = 0,
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
  final String creatorName;
  final String genreName;
  final String aiToolName;
  final String? reviewNote;
  final int likeCount;
  final int commentCount;
  final int episodeCount;

  /// The Series Jeen id when this film comes from the catalog, else null.
  final int? catalogDramaId;

  /// Every genre a catalog series is listed under; [genreName] is the first.
  final List<String> genreTags;

  /// Running time of all episodes, from the backend.
  final int totalDurationSec;

  factory Film.fromJson(Map<String, dynamic> json) => Film(
    id: json['id'] as int,
    creatorId: json['creator_id'] as int,
    title: json['title'] as String,
    synopsis: json['synopsis'] as String?,
    posterUrl: json['poster_url'] as String?,
    genreId: json['genre_id'] as int,
    aiToolId: json['ai_tool_id'] as int,
    promptCredit: json['prompt_credit'] as String?,
    // The API sends booleans; older fixtures send 0/1.
    isAiGenerated:
        json['is_ai_generated'] == 1 || json['is_ai_generated'] == true,
    status: json['status'] as String,
    creatorName: (json['creator'] as Map?)?['name'] as String? ?? '',
    genreName: json['genre'] as String? ?? '',
    aiToolName: json['ai_tool'] as String? ?? '',
    reviewNote: json['review_note'] as String?,
    likeCount: json['like_count'] as int? ?? 0,
    commentCount: json['comment_count'] as int? ?? 0,
    episodeCount: json['episode_count'] as int? ?? 0,
    totalDurationSec: json['total_duration_sec'] as int? ?? 0,
  );

  Film copyWith({
    String? title,
    int? genreId,
    int? aiToolId,
    String? promptCredit,
    String? status,
    String? reviewNote,
    bool clearReviewNote = false,
    String? genreName,
    String? aiToolName,
    int? likeCount,
    int? commentCount,
  }) {
    return Film(
      id: id,
      creatorId: creatorId,
      title: title ?? this.title,
      synopsis: synopsis,
      posterUrl: posterUrl,
      genreId: genreId ?? this.genreId,
      aiToolId: aiToolId ?? this.aiToolId,
      promptCredit: promptCredit ?? this.promptCredit,
      isAiGenerated: isAiGenerated,
      status: status ?? this.status,
      creatorName: creatorName,
      genreName: genreName ?? this.genreName,
      aiToolName: aiToolName ?? this.aiToolName,
      reviewNote: clearReviewNote ? null : reviewNote ?? this.reviewNote,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      episodeCount: episodeCount,
      catalogDramaId: catalogDramaId,
      genreTags: genreTags,
      totalDurationSec: totalDurationSec,
    );
  }
}
