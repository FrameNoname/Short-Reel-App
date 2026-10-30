class Episode {
  const Episode({
    required this.id,
    required this.filmId,
    required this.episodeNo,
    required this.title,
    required this.durationSec,
    required this.isFree,
    required this.priceCoins,
  });

  final int id;
  final int filmId;
  final int episodeNo;
  final String? title;
  final int durationSec;
  final bool isFree;
  final int priceCoins;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: json['id'] as int,
    filmId: json['film_id'] as int,
    episodeNo: json['episode_no'] as int,
    title: json['title'] as String?,
    durationSec: json['duration_sec'] as int,
    isFree: json['is_free'] == 1,
    priceCoins: json['price_coins'] as int,
  );
}
