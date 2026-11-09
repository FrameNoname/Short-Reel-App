/// What the admin screens read from `/api/admin`.
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// Coins one film earned from unlocks.
class FilmSales {
  const FilmSales({
    required this.filmId,
    required this.title,
    required this.unlockCount,
    required this.coinsSpent,
  });

  final int filmId;
  final String title;
  final int unlockCount;
  final int coinsSpent;

  factory FilmSales.fromJson(Map<String, dynamic> json) => FilmSales(
    filmId: _int(json['film_id']),
    title: json['title'] as String,
    unlockCount: _int(json['unlock_count']),
    coinsSpent: _int(json['coins_spent']),
  );
}

class AdminFilm {
  const AdminFilm({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.takenDown,
    required this.episodeCount,
    required this.likeCount,
    required this.commentCount,
    required this.coinsSpent,
    this.catalogDramaId,
  });

  /// 0 for a Series Jeen series nobody bought or took down yet.
  final int id;
  final String title;
  final String? posterUrl;

  /// Set for a Series Jeen series.
  final int? catalogDramaId;
  bool get isCatalog => catalogDramaId != null;
  final bool takenDown;
  final int episodeCount;
  final int likeCount;
  final int commentCount;
  final int coinsSpent;

  factory AdminFilm.fromJson(Map<String, dynamic> json) => AdminFilm(
    id: _int(json['id']),
    title: json['title'] as String,
    posterUrl: json['poster_url'] as String?,
    takenDown: json['status'] == 'taken_down',
    episodeCount: _int(json['episode_count']),
    likeCount: _int(json['like_count']),
    commentCount: _int(json['comment_count']),
    coinsSpent: _int(json['coins_spent']),
    catalogDramaId: (json['catalog_drama_id'] as num?)?.toInt(),
  );

  AdminFilm withTakenDown(bool value) => AdminFilm(
    id: id,
    title: title,
    posterUrl: posterUrl,
    takenDown: value,
    episodeCount: episodeCount,
    likeCount: likeCount,
    commentCount: commentCount,
    coinsSpent: coinsSpent,
    catalogDramaId: catalogDramaId,
  );

  /// Same film, either as a listed row or a search result.
  bool sameAs(AdminFilm other) => isCatalog
      ? catalogDramaId == other.catalogDramaId
      : !other.isCatalog && id == other.id;
}

class AdminEpisode {
  const AdminEpisode({
    required this.id,
    required this.episodeNo,
    required this.title,
    required this.isFree,
    required this.priceCoins,
    required this.unlockCount,
  });

  final int id;
  final int episodeNo;
  final String? title;
  final bool isFree;
  final int priceCoins;
  final int unlockCount;

  factory AdminEpisode.fromJson(Map<String, dynamic> json) => AdminEpisode(
    id: _int(json['id']),
    episodeNo: _int(json['episode_no']),
    title: json['title'] as String?,
    isFree: json['is_free'] == true,
    priceCoins: _int(json['price_coins']),
    unlockCount: _int(json['unlock_count']),
  );

  AdminEpisode copyWith({required bool isFree, required int priceCoins}) =>
      AdminEpisode(
        id: id,
        episodeNo: episodeNo,
        title: title,
        isFree: isFree,
        priceCoins: priceCoins,
        unlockCount: unlockCount,
      );
}

class AdminComment {
  const AdminComment({
    required this.id,
    required this.body,
    required this.username,
    required this.filmTitle,
    required this.createdAt,
  });

  final int id;
  final String body;
  final String username;
  final String filmTitle;
  final DateTime createdAt;

  factory AdminComment.fromJson(Map<String, dynamic> json) => AdminComment(
    id: _int(json['id']),
    body: json['body'] as String,
    username: json['username'] as String,
    filmTitle: json['film_title'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

class AdminCoinPack {
  const AdminCoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.priceUsd,
    required this.soldCount,
  });

  final int id;
  final String name;
  final int coins;
  final double priceUsd;
  final int soldCount;

  factory AdminCoinPack.fromJson(Map<String, dynamic> json) => AdminCoinPack(
    id: _int(json['id']),
    name: json['name'] as String,
    coins: _int(json['coins']),
    priceUsd: (json['price_usd'] as num).toDouble(),
    soldCount: _int(json['sold_count']),
  );
}

/// The prices and amounts the admin can change without touching the code.
class AdminSettings {
  const AdminSettings({
    this.demoTopUpCoins = 100,
    this.catalogFreeEpisodes = 5,
    this.catalogPriceCoins = 10,
  });

  final int demoTopUpCoins;
  final int catalogFreeEpisodes;
  final int catalogPriceCoins;

  factory AdminSettings.fromJson(Map<String, dynamic> json) => AdminSettings(
    demoTopUpCoins: _int(json['demo_topup_coins'] ?? 100),
    catalogFreeEpisodes: _int(json['catalog_free_episodes'] ?? 5),
    catalogPriceCoins: _int(json['catalog_price_coins'] ?? 10),
  );

  Map<String, dynamic> toJson() => {
    'demo_topup_coins': demoTopUpCoins,
    'catalog_free_episodes': catalogFreeEpisodes,
    'catalog_price_coins': catalogPriceCoins,
  };
}
