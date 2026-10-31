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
    this.posterAsset,
    this.reviewNote,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.episodeCount = 0,
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
  final String? posterAsset;
  final String? reviewNote;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final int episodeCount;

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
      posterAsset: posterAsset,
      reviewNote: clearReviewNote ? null : reviewNote ?? this.reviewNote,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount,
      episodeCount: episodeCount,
    );
  }
}
