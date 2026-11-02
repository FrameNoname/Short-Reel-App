import '../models/catalog.dart';
import '../models/coin_pack.dart';
import 'dart:typed_data';

import '../models/episode.dart';
import '../models/film.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'film_filter.dart';

export '../models/episode.dart' show EpisodeAccess;

class Earnings {
  const Earnings({
    required this.coins,
    required this.unlocks,
    required this.likes,
    this.coinsByFilm = const {},
    this.adminSharePercent,
  });

  final int coins;
  final int unlocks;

  final int likes;

  /// Coins the channel earned from each of its films, by film id.
  final Map<int, int> coinsByFilm;

  /// The admin's current cut, so a creator can see how earnings are split.
  final int? adminSharePercent;
}

/// Coins and dollars are different units and are kept in separate fields.
class AdminSales {
  const AdminSales({
    required this.totalUsd,
    required this.adminCoins,
    this.coinsSpent = 0,
    this.creatorCoins = 0,
    this.unlockCount = 0,
  });

  /// Simulated payments (coin packs and subscriptions) in dollars.
  final double totalUsd;

  /// The admin's share of the coins viewers spent on unlocks.
  final int adminCoins;
  final int coinsSpent;
  final int creatorCoins;
  final int unlockCount;
}

/// One episode of an upload: the picked video and the price chosen for it.
class EpisodeDraft {
  const EpisodeDraft({
    required this.fileName,
    required this.priceCoins,
    this.bytes,
    this.path,
  });

  final String fileName;
  final int priceCoins;

  /// The video itself: bytes on the web, a file path on a phone.
  final Uint8List? bytes;
  final String? path;
}

/// What a player needs to start an episode.
class Playback {
  const Playback({required this.episode, required this.streamUrl});

  final Episode episode;

  /// Null when the viewer may not watch it yet.
  final String? streamUrl;
}

class FilmReport {
  const FilmReport({
    required this.id,
    required this.filmId,
    required this.filmTitle,
    required this.reason,
    required this.isOpen,
  });

  final int id;
  final int filmId;
  final String filmTitle;
  final String reason;
  final bool isOpen;
}

class FilmComment {
  const FilmComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.body,
    this.parentId,
  });

  final int id;
  final int userId;
  final String username;
  final String body;

  /// The comment this one replies to; null for a top-level comment.
  final int? parentId;

  bool get isReply => parentId != null;
}

class EpisodePricing {
  const EpisodePricing({
    required this.freeCount,
    required this.paidCount,
    required this.priceCoins,
    int? maxPriceCoins,
  }) : maxPriceCoins = maxPriceCoins ?? priceCoins;

  final int freeCount;
  final int paidCount;

  /// The lowest price among the paid episodes, or 0 when none are paid.
  final int priceCoins;

  /// The highest price among the paid episodes.
  final int maxPriceCoins;

  bool get hasMixedPrices => maxPriceCoins != priceCoins;
}

/// Everything the screens need. [MockRepository] answers from demo data; an
/// API-backed version can replace it once the backend endpoints are ready.
abstract class AppRepository {
  /// The public profile behind a channel, or null when the id is unknown.
  User? userById(int id);

  /// Channels (creators and admins) whose name matches [query].
  List<User> searchCreators(String query);

  /// One film by id, or null when it does not exist.
  Film? filmById(int id);

  /// The admin's film for a catalog series, added on first use so any series
  /// in the catalog can be opened like a feed film.
  Film catalogFilm(CatalogDrama drama);

  /// Genres of the catalog films, the most common first, for the filters.
  List<String> catalogGenres();

  /// Saves the person's channel name and bio.
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  });
  Future<User> login(String username, String password);
  Future<User> register(String username, String password, UserRole role);

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

  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]);
  Future<List<Film>> followingFilms(int userId);
  Future<List<Episode>> episodes(int filmId);
  EpisodeAccess accessOf(int? userId, Episode episode);
  List<FilmComment> commentsOf(int filmId);
  Future<void> addComment(int userId, int filmId, String body, {int? parentId});

  /// Loads the comments of [filmId] so [commentsOf] can answer.
  Future<void> loadComments(int filmId);

  /// Removes a comment together with the replies under it.
  Future<void> removeComment(int commentId);
  bool isCommentLiked(int userId, int commentId);
  int commentLikeCount(int commentId);
  void toggleCommentLike(int userId, int commentId);
  Future<void> reportFilm(int userId, int filmId, String reason);

  /// Reads the current balance from the server (it may have changed elsewhere).
  Future<User> refreshBalance(int userId);
  Future<User> unlock(int userId, int episodeId);

  /// Simulated purchase of [pack]; the server decides what it is worth.
  Future<User> topUpPack(int userId, CoinPack pack);

  /// The demo button: [demoTopUpCoins] coins for nothing.
  Future<User> demoTopUp(int userId);
  Future<Subscription> subscribe(int userId);
  Future<Subscription?> subscriptionOf(int userId);
  Future<void> cancelSubscription(int userId);

  /// Plan price, typical episode price and demo coins; the API versions are
  /// refreshed by [coinPacks].
  double get subscriptionPriceUsd;
  int get episodePriceCoins;
  Future<List<Transaction>> transactionsOf(int userId);
  Future<List<CoinPack>> coinPacks();
  int get demoTopUpCoins;

  bool isLiked(int userId, int filmId);
  bool isSaved(int userId, int filmId);
  bool isFollowing(int userId, int creatorId);
  Future<void> toggleLike(int userId, int filmId);
  Future<void> toggleSave(int userId, int filmId);
  Future<void> toggleFollow(int userId, int creatorId);

  /// Loads what [watchlistOf], [unlockedFilmsOf] and [followingOf] answer from.
  Future<void> refreshLibrary(int userId);
  List<Film> watchlistOf(int userId);
  List<Film> unlockedFilmsOf(int userId);
  List<User> followingOf(int userId);

  int followerCount(int userId);

  Future<Film> upload({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<EpisodeDraft> episodes,
  });
  Future<void> updateFilm(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,

    /// New prices by episode id, saved together with the details or not at all.
    Map<int, int> episodePrices = const {},
  });
  Future<void> deleteFilm(int filmId);

  /// Sets new prices by episode id; 0 coins makes an episode free.
  Future<void> setEpisodePrices(Map<int, int> pricesByEpisodeId);
  Future<EpisodePricing> pricingOf(int filmId);
  Future<List<Film>> filmsOf(int creatorId);
  Future<Earnings> earningsOf(int creatorId);

  Future<List<Film>> reviewQueue();
  Future<List<Film>> liveFilms();
  Future<void> review(int filmId, String status, {String? note});
  Future<List<FilmReport>> openReports();
  Future<void> resolveReport(int reportId);
  Future<AdminSales> adminSales();
  Future<int> adminSharePercent();
  Future<void> setAdminSharePercent(int percent);
}
