enum EpisodeAccess { free, unlocked, plus, locked }

class Episode {
  const Episode({
    required this.id,
    required this.filmId,
    required this.episodeNo,
    required this.title,
    required this.durationSec,
    required this.isFree,
    required this.priceCoins,
    this.access,
  });

  final int id;
  final int filmId;
  final int episodeNo;
  final String? title;
  final int durationSec;
  final bool isFree;
  final int priceCoins;

  /// What the backend says this viewer may do; null for the offline mock,
  /// which works it out from its own records.
  final EpisodeAccess? access;

  /// The same episode at a new price; 0 coins makes it free.
  Episode withPrice(int coins) => Episode(
    id: id,
    filmId: filmId,
    episodeNo: episodeNo,
    title: title,
    durationSec: durationSec,
    isFree: coins == 0,
    priceCoins: coins,
  );

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: json['id'] as int,
    filmId: json['film_id'] as int,
    episodeNo: json['episode_no'] as int,
    title: json['title'] as String?,
    durationSec: json['duration_sec'] as int,
    // The API sends booleans; older fixtures send 0/1.
    isFree: json['is_free'] == 1 || json['is_free'] == true,
    priceCoins: json['price_coins'] as int,
    access: _accessFromApi(json['access'] as String?),
  );

  static EpisodeAccess? _accessFromApi(String? value) => switch (value) {
    'free' => EpisodeAccess.free,
    'owner' || 'unlocked' => EpisodeAccess.unlocked,
    'subscription' => EpisodeAccess.plus,
    'locked' || 'login_required' => EpisodeAccess.locked,
    _ => null,
  };
}
