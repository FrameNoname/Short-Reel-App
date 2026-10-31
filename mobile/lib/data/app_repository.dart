import '../models/app_notification.dart';
import '../models/coin_pack.dart';
import '../models/episode.dart';
import '../models/film.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'film_filter.dart';

enum EpisodeAccess { free, unlocked, plus, locked }

class Earnings {
  const Earnings({
    required this.coins,
    required this.unlocks,
    required this.views,
    required this.likes,
  });

  final int coins;
  final int unlocks;
  final int views;
  final int likes;
}

/// One day of a channel's numbers.
class DailyStat {
  const DailyStat({
    required this.day,
    required this.views,
    required this.likes,
    required this.coins,
  });

  final DateTime day;
  final int views;
  final int likes;
  final int coins;
}

class AdminSales {
  const AdminSales({required this.totalUsd, required this.adminCoins});

  final double totalUsd;
  final int adminCoins;
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

/// How far a person has got in a film they have not finished.
class WatchProgress {
  const WatchProgress({required this.film, required this.episodeNo});

  final Film film;
  final int episodeNo;

  /// Share of the film's episodes reached, from 0 to 1.
  double get fraction =>
      film.episodeCount == 0 ? 0 : episodeNo / film.episodeCount;
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

  /// The person's inbox, newest first.
  List<AppNotification> notificationsOf(int userId);
  int unreadNotificationCount(int userId);
  void markNotificationsRead(int userId);

  /// Saves the person's channel name and bio.
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  });
  Future<User> login(String username, String password);
  Future<User> register(String username, String password, UserRole role);

  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]);
  Future<List<Film>> followingFilms(int userId);
  Future<List<Episode>> episodes(int filmId);
  EpisodeAccess accessOf(int? userId, Episode episode);
  List<FilmComment> commentsOf(int filmId);
  void addComment(int userId, int filmId, String body, {int? parentId});

  /// Removes a comment together with the replies under it.
  void removeComment(int commentId);
  bool isCommentLiked(int userId, int commentId);
  int commentLikeCount(int commentId);
  void toggleCommentLike(int userId, int commentId);
  void reportFilm(int userId, int filmId, String reason);

  Future<User> unlock(int userId, int episodeId);
  Future<User> topUp(int userId, {required int coins, double priceUsd = 0});
  Future<Subscription> subscribe(int userId);
  Subscription? subscriptionOf(int userId);
  void cancelSubscription(int userId);
  double get subscriptionPriceUsd;
  int get episodePriceCoins;
  List<Transaction> transactionsOf(int userId);
  List<CoinPack> coinPacks();
  int get demoTopUpCoins;

  bool isLiked(int userId, int filmId);
  bool isSaved(int userId, int filmId);
  bool isFollowing(int userId, int creatorId);
  void toggleLike(int userId, int filmId);
  void toggleSave(int userId, int filmId);
  void toggleFollow(int userId, int creatorId);
  List<Film> watchlistOf(int userId);
  List<Film> unlockedFilmsOf(int userId);
  List<User> followingOf(int userId);

  /// Remembers that [userId] reached [episodeNo] of a film.
  void recordProgress(int userId, int filmId, int episodeNo);

  /// Unfinished films, the one watched most recently first.
  List<WatchProgress> continueWatching(int userId);
  int followerCount(int userId);

  Future<Film> upload({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<int> episodePrices,
  });
  void updateFilm(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
  });
  void deleteFilm(int filmId);

  /// Sets new prices by episode id; 0 coins makes an episode free.
  void setEpisodePrices(Map<int, int> pricesByEpisodeId);
  EpisodePricing pricingOf(int filmId);
  List<Film> filmsOf(int creatorId);
  Earnings earningsOf(int creatorId);

  /// The channel's numbers for each of the last [days] days, oldest first.
  List<DailyStat> dailyStatsOf(int creatorId, {int days = 60});
  int earningsOfFilm(int filmId);

  List<Film> reviewQueue();
  List<Film> liveFilms();
  void review(int filmId, String status, {String? note});
  List<FilmReport> openReports();
  void resolveReport(int reportId);
  AdminSales adminSales();
  int get adminSharePercent;
  void setAdminSharePercent(int percent);
}
