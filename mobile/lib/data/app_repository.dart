import '../models/admin.dart';
import '../models/catalog.dart';
import '../models/coin_pack.dart';

import '../models/episode.dart';
import '../models/film.dart';
import '../models/transaction.dart';
import '../models/user.dart';

export '../models/admin.dart';
export '../models/episode.dart' show EpisodeAccess;

/// Coins and dollars are different units and are kept in separate fields.
class AdminSales {
  const AdminSales({
    required this.totalUsd,
    this.coinsSpent = 0,
    this.unlockCount = 0,
    this.perFilm = const [],
  });

  /// Films that sold at least one unlock, best seller first.
  final List<FilmSales> perFilm;

  /// Simulated payments (coin packs) in dollars.
  final double totalUsd;

  /// Coins viewers spent on unlocks; all of them go to the admin.
  final int coinsSpent;
  final int unlockCount;
}

/// What a player needs to start an episode.
class Playback {
  const Playback({required this.episode, required this.streamUrl});

  final Episode episode;

  /// Null when the viewer may not watch it yet.
  final String? streamUrl;
}

class FilmComment {
  const FilmComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.body,
  });

  final int id;
  final int userId;
  final String username;
  final String body;
}

/// Everything the screens need. [ApiRepository] answers from the REST API.
abstract class AppRepository {
  /// One film by id, or null when it does not exist.
  Film? filmById(int id);

  /// The admin's film for a catalog series, added on first use so any series
  /// in the catalog can be opened like a feed film.
  Film catalogFilm(CatalogDrama drama);

  /// Saves the person's channel name and bio.
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  });
  Future<User> login(String username, String password);
  Future<User> register(String username, String password);

  /// Signs back in from the stored token on app start; null when there is none.
  Future<User?> restoreSession();

  /// Forgets the token. The server keeps nothing to revoke.
  Future<void> logout();

  /// Drops the token and everything held for the person without calling the
  /// server, for when it has already refused the token.
  Future<void> clearSession();

  /// True when episodes play real video from the backend; the offline mock
  /// only shows a placeholder.
  bool get playsVideo;

  /// Asks the backend whether [episodeId] may be watched and for its link.
  Future<Playback> playback(int episodeId);

  /// Approved films whose title matches [query].
  Future<List<Film>> films([String query = '']);
  Future<List<Episode>> episodes(int filmId);
  EpisodeAccess accessOf(int? userId, Episode episode);

  /// Whether this viewer must pay before a catalog episode plays. Always
  /// false for the app's own films.
  bool catalogEpisodeLocked(Film film, int episodeNo);
  List<FilmComment> commentsOf(int filmId);
  Future<void> addComment(int userId, int filmId, String body);

  /// Loads the comments of [filmId] so [commentsOf] can answer.
  Future<void> loadComments(int filmId);

  Future<void> removeComment(int commentId);

  /// Reads the current balance from the server (it may have changed elsewhere).
  Future<User> refreshBalance(int userId);
  Future<User> unlock(int userId, int episodeId);

  /// Simulated purchase of [pack]; the server decides what it is worth.
  Future<User> topUpPack(int userId, CoinPack pack);

  /// The demo button: [demoTopUpCoins] coins for nothing.
  Future<User> demoTopUp(int userId);

  /// Typical episode price and demo coins; the API versions are refreshed by
  /// [coinPacks].
  int get episodePriceCoins;
  Future<List<Transaction>> transactionsOf(int userId);
  Future<List<CoinPack>> coinPacks();
  int get demoTopUpCoins;

  bool isLiked(int userId, int filmId);
  bool isSaved(int userId, int filmId);
  Future<void> toggleLike(int userId, int filmId);
  Future<void> toggleSave(int userId, int filmId);

  /// Loads what [watchlistOf] and [unlockedFilmsOf] answer from.
  Future<void> refreshLibrary(int userId);
  List<Film> watchlistOf(int userId);
  List<Film> unlockedFilmsOf(int userId);

  Future<AdminSales> adminSales();

  // Admin: content, comments and settings.
  Future<List<AdminFilm>> adminFilms();
  Future<void> adminSetFilmTakenDown(AdminFilm film, bool takenDown);
  Future<List<AdminFilm>> adminSearchCatalog(String query);
  Future<List<AdminEpisode>> adminEpisodes(int filmId);
  Future<AdminEpisode> adminUpdateEpisode(
    AdminEpisode episode, {
    required bool isFree,
    required int priceCoins,
  });
  Future<List<AdminComment>> adminComments();
  Future<void> adminDeleteComment(int commentId);
  Future<AdminSettings> adminSettings();
  Future<AdminSettings> adminSaveSettings(AdminSettings settings);
  Future<List<AdminCoinPack>> adminCoinPacks();
  Future<void> adminSaveCoinPack({
    int? id,
    required String name,
    required int coins,
    required double priceUsd,
  });
  Future<void> adminDeleteCoinPack(int id);
}
