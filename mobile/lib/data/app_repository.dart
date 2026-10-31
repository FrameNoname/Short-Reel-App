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
  });

  final int id;
  final int userId;
  final String username;
  final String body;
}

class EpisodePricing {
  const EpisodePricing({
    required this.freeCount,
    required this.paidCount,
    required this.priceCoins,
  });

  final int freeCount;
  final int paidCount;
  final int priceCoins;
}

/// Everything the screens need. [MockRepository] answers from demo data; an
/// API-backed version can replace it once the backend endpoints are ready.
abstract class AppRepository {
  Future<User> login(String username, String password);
  Future<User> register(String username, String password, UserRole role);

  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]);
  Future<List<Film>> followingFilms(int userId);
  Future<List<Episode>> episodes(int filmId);
  EpisodeAccess accessOf(int? userId, Episode episode);
  List<FilmComment> commentsOf(int filmId);
  void addComment(int userId, int filmId, String body);
  void removeComment(int commentId);
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
  int followerCount(int userId);

  Future<Film> upload({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<bool> episodeFree,
  });
  void updateFilm(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
  });
  void deleteFilm(int filmId);
  EpisodePricing pricingOf(int filmId);
  List<Film> filmsOf(int creatorId);
  Earnings earningsOf(int creatorId);
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
