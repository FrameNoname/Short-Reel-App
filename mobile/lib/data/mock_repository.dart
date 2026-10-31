import 'dart:math' as math;

import '../models/app_notification.dart';
import '../models/coin_pack.dart';
import '../models/episode.dart';
import '../models/catalog.dart';
import '../models/film.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import 'app_repository.dart';
import 'film_filter.dart';
import 'mock_data.dart';

/// In-memory backend for the UI demo. Data resets when the app restarts.
class MockRepository implements AppRepository {
  MockRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    for (final film in _films.values) {
      for (var n = 1; n <= film.episodeCount; n++) {
        _addEpisode(film.id, n, price: n <= 2 ? 0 : _episodePrice);
      }
    }
    _seedUnlocks();
    _seedWallets();
    _seedNotifications();
  }

  static const _episodePrice = 20;
  static const _subscriptionPrice = 6.99;

  final DateTime _now;
  final Map<int, User> _users = {for (final u in mockUsers) u.id: u};
  final Map<String, String> _passwords = Map.of(mockPasswords);
  final Map<int, Film> _films = {for (final f in mockFilms) f.id: f};
  final Map<int, Episode> _episodes = {};
  final Map<int, List<Transaction>> _transactions = {};
  final Map<int, Subscription> _subscriptions = {};
  final List<_Unlock> _unlocks = [];
  final Set<(int, int)> _likes = {(4, 1), (6, 3)};
  final Set<(int, int)> _saved = {(4, 2), (4, 3), (6, 1)};
  final Set<(int, int)> _follows = {(4, 2), (4, 3), (6, 4)};
  final List<FilmReport> _reports = [
    const FilmReport(
      id: 1,
      filmId: 2,
      filmTitle: 'Paper Moons',
      reason: 'Audio out of sync in episode 4',
      isOpen: true,
    ),
  ];

  final List<FilmComment> _comments = [
    const FilmComment(
      id: 1,
      userId: 6,
      username: 'viewer01',
      body: 'The ending of episode 2 was great!',
    ),
    const FilmComment(
      id: 2,
      userId: 4,
      username: 'mira.lens',
      body: 'Love the paper-cut style.',
    ),
  ];
  final Map<int, int> _commentFilm = {1: 1, 2: 2};

  /// (userId, commentId) pairs for every like on a comment.
  final Set<(int, int)> _commentLikes = {(6, 2), (3, 2), (2, 1)};
  int _nextCommentId = 3;

  final Map<int, List<AppNotification>> _notifications = {};
  int _nextNotificationId = 1;

  /// (filmId, episodeNo) per person, the most recent first.
  final Map<int, List<(int, int)>> _progress = {};

  int _adminSharePercent = 30;
  double _salesUsd = 8.97;
  int _nextEpisodeId = 1;

  void _addEpisode(
    int filmId,
    int number, {
    required int price,
    int? durationSec,
  }) {
    final id = _nextEpisodeId++;
    _episodes[id] = Episode(
      id: id,
      filmId: filmId,
      episodeNo: number,
      title: 'Episode $number',
      durationSec: durationSec ?? 60 + number * 15,
      isFree: price == 0,
      priceCoins: price,
    );
  }

  static const catalogFilmIdBase = 100000000;
  static const _catalogAdminId = 1;
  static const _catalogPlatforms = 3;
  static const _catalogPerPlatform = 12;

  Future<void>? _catalogLoading;

  /// Puts series from the Series Jeen catalog at the top of the feed, owned by
  /// the admin. The feed waits for them, and a failed call just leaves the
  /// demo films.
  void useCatalog(CatalogService service) {
    _catalogLoading = _loadCatalog(service).catchError((Object _) {});
  }

  Future<void> _loadCatalog(CatalogService service) async {
    final platforms = (await service.platforms())
        .where((p) => p.hasAccess)
        .take(_catalogPlatforms);
    final lists = <List<CatalogDrama>>[];
    for (final platform in platforms) {
      final page = await service.dramas(platform.id);
      // A series without artwork would be a blank tile in the feed and search.
      final withPoster = page.items.where((d) => d.posterUrl != null);
      lists.add(withPoster.take(_catalogPerPlatform).toList());
    }
    // One title from each platform in turn, so the feed mixes them.
    final dramas = <CatalogDrama>[
      for (var i = 0; i < _catalogPerPlatform; i++)
        for (final list in lists)
          if (i < list.length) list[i],
    ];
    // Catalog films go first in the feed, ahead of the demo films.
    final listed = {
      for (final drama in dramas)
        catalogFilmIdBase + drama.id: catalogFilm(drama),
    };
    final rest = {
      for (final e in _films.entries)
        if (!listed.containsKey(e.key)) e.key: e.value,
    };
    _films
      ..clear()
      ..addAll(listed)
      ..addAll(rest);
  }

  @override
  Film catalogFilm(CatalogDrama drama) {
    final id = catalogFilmIdBase + drama.id;
    final existing = _films[id];
    if (existing != null) return existing;
    final film = _filmFromDrama(drama);
    _films[id] = film;
    for (var n = 1; n <= film.episodeCount; n++) {
      _addEpisode(id, n, price: 0, durationSec: 0);
    }
    return film;
  }

  static const _maxCatalogGenres = 12;

  @override
  List<String> catalogGenres() {
    final counts = <String, int>{};
    for (final film in _films.values) {
      for (final tag in film.genreTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names.take(_maxCatalogGenres).toList();
  }

  Film _filmFromDrama(CatalogDrama drama) => Film(
    id: catalogFilmIdBase + drama.id,
    creatorId: _catalogAdminId,
    title: drama.title,
    synopsis: drama.description,
    posterUrl: drama.posterUrl,
    genreId: 0,
    aiToolId: 0,
    promptCredit: null,
    isAiGenerated: false,
    status: 'approved',
    creatorName: _users[_catalogAdminId]!.username,
    genreName: drama.genres.isEmpty ? '' : drama.genres.first,
    genreTags: drama.genres,
    episodeCount: drama.episodeCount,
    catalogDramaId: drama.id,
  );

  void _seedNotifications() {
    void seed(
      int to,
      NotificationKind kind,
      Duration ago, {
      int? actor,
      int? film,
      int? episode,
      bool read = false,
    }) {
      _notifications
          .putIfAbsent(to, () => [])
          .add(
            AppNotification(
              id: _nextNotificationId++,
              userId: to,
              kind: kind,
              createdAt: _now.subtract(ago),
              actorId: actor,
              actorName: actor == null ? '' : _users[actor]!.username,
              filmId: film,
              filmTitle: film == null ? '' : _films[film]!.title,
              episodeNo: episode,
              read: read,
            ),
          );
    }

    // The newest first, since each list is read top to bottom.
    seed(2, NotificationKind.like, const Duration(hours: 2), actor: 4, film: 1);
    seed(
      2,
      NotificationKind.comment,
      const Duration(hours: 5),
      actor: 6,
      film: 1,
    );
    seed(
      2,
      NotificationKind.follow,
      const Duration(days: 1),
      actor: 6,
      read: true,
    );
    seed(
      2,
      NotificationKind.unlock,
      const Duration(days: 3),
      actor: 4,
      film: 1,
      episode: 3,
      read: true,
    );
    seed(
      6,
      NotificationKind.reply,
      const Duration(hours: 1),
      actor: 4,
      film: 1,
    );
    seed(
      4,
      NotificationKind.like,
      const Duration(minutes: 30),
      actor: 6,
      film: 3,
    );
    seed(
      4,
      NotificationKind.unlock,
      const Duration(days: 1),
      actor: 6,
      film: 3,
      episode: 3,
      read: true,
    );
  }

  /// Tells [recipientId] about something. Nobody hears about their own
  /// actions, and a repeated like or follow does not pile up.
  void _notify(
    int recipientId,
    NotificationKind kind, {
    int? actorId,
    int? filmId,
    int? episodeNo,
  }) {
    if (actorId != null && actorId == recipientId) return;
    final list = _notifications.putIfAbsent(recipientId, () => []);
    final repeatable =
        kind == NotificationKind.like || kind == NotificationKind.follow;
    if (repeatable &&
        list.any(
          (n) =>
              !n.read &&
              n.kind == kind &&
              n.actorId == actorId &&
              n.filmId == filmId,
        )) {
      return;
    }
    list.insert(
      0,
      AppNotification(
        id: _nextNotificationId++,
        userId: recipientId,
        kind: kind,
        createdAt: DateTime.now(),
        actorId: actorId,
        actorName: actorId == null ? '' : _user(actorId).username,
        filmId: filmId,
        filmTitle: filmId == null ? '' : _films[filmId]!.title,
        episodeNo: episodeNo,
      ),
    );
  }

  @override
  Film? filmById(int id) => _films[id];

  @override
  List<AppNotification> notificationsOf(int userId) =>
      List.unmodifiable(_notifications[userId] ?? const []);

  @override
  int unreadNotificationCount(int userId) =>
      (_notifications[userId] ?? const []).where((n) => !n.read).length;

  @override
  void markNotificationsRead(int userId) {
    final list = _notifications[userId];
    if (list == null) return;
    _notifications[userId] = [for (final n in list) n.asRead()];
  }

  void _seedUnlocks() {
    void seed(int userId, int filmId, int number, int creator, int admin) {
      final episode = _episodes.values.firstWhere(
        (e) => e.filmId == filmId && e.episodeNo == number,
      );
      _unlocks.add(_Unlock(userId, episode.id, creator, admin));
    }

    seed(4, 1, 3, 14, 6);
    seed(4, 1, 4, 14, 6);
    seed(6, 3, 3, 14, 6);
    seed(4, 5, 3, 0, 20);
  }

  void _seedWallets() {
    DateTime daysAgo(int days) => _now.subtract(Duration(days: days));

    // Newest first, adding up to the balances in mock_data.dart.
    _transactions[4] = [
      Transaction(
        id: 6,
        type: 'unlock',
        amount: -20,
        balanceAfter: 142,
        createdAt: daysAgo(2),
        label: 'ShortReel Intro, Episode 3',
      ),
      Transaction(
        id: 5,
        type: 'unlock',
        amount: -20,
        balanceAfter: 162,
        createdAt: daysAgo(3),
        label: 'Salt & Signal, Episode 4',
      ),
      Transaction(
        id: 4,
        type: 'unlock',
        amount: -20,
        balanceAfter: 182,
        createdAt: daysAgo(3),
        label: 'Salt & Signal, Episode 3',
      ),
      Transaction(
        id: 3,
        type: 'topup',
        amount: 42,
        balanceAfter: 202,
        createdAt: daysAgo(4),
        label: 'Demo top-up',
      ),
      Transaction(
        id: 2,
        type: 'topup',
        amount: 60,
        balanceAfter: 160,
        createdAt: daysAgo(6),
        label: 'Demo top-up',
      ),
      Transaction(
        id: 1,
        type: 'topup',
        amount: 100,
        balanceAfter: 100,
        createdAt: daysAgo(7),
        label: 'Demo top-up',
      ),
    ];
    _transactions[6] = [
      Transaction(
        id: 8,
        type: 'unlock',
        amount: -20,
        balanceAfter: 80,
        createdAt: daysAgo(1),
        label: 'Ember Protocol, Episode 3',
      ),
      Transaction(
        id: 7,
        type: 'topup',
        amount: 100,
        balanceAfter: 100,
        createdAt: daysAgo(2),
        label: 'Demo top-up',
      ),
    ];
    _subscriptions[4] = Subscription(
      id: 1,
      priceUsd: _subscriptionPrice,
      startDate: daysAgo(10),
      endDate: _now.add(const Duration(days: 20)),
    );
  }

  ApiException _error(String code, String message, int status) =>
      ApiException(code: code, message: message, statusCode: status);

  User _user(int id) => _users[id]!;

  @override
  User? userById(int id) => _users[id];

  @override
  List<User> searchCreators(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return _users.values
        .where((u) => u.role == UserRole.creator || u.role == UserRole.admin)
        .where(
          (u) =>
              u.username.toLowerCase().contains(needle) ||
              (u.displayName ?? '').toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw _error('VALIDATION', 'Enter a name for your channel.', 400);
    }
    final updated = _user(userId).copyWith(displayName: name, bio: bio.trim());
    _users[userId] = updated;
    return updated;
  }

  @override
  Future<User> login(String username, String password) async {
    final name = username.trim();
    if (_passwords[name] != password) {
      throw _error(
        'UNAUTHENTICATED',
        'Username or password is incorrect. Please try again.',
        401,
      );
    }
    return _users.values.firstWhere((u) => u.username == name);
  }

  @override
  Future<User> register(String username, String password, UserRole role) async {
    final name = username.trim();
    if (_passwords.containsKey(name)) {
      throw _error('CONFLICT', 'This username is already taken.', 409);
    }
    final id = _users.keys.reduce((a, b) => a > b ? a : b) + 1;
    final user = User(
      id: id,
      username: name,
      displayName: name,
      role: role,
      coinBalance: 0,
    );
    _users[id] = user;
    _passwords[name] = password;
    return user;
  }

  bool _matches(Film film, FilmFilter filter) {
    if (filter.genres.isNotEmpty &&
        !filter.genres.contains(film.genreName) &&
        !film.genreTags.any(filter.genres.contains)) {
      return false;
    }
    if (filter.aiTools.isNotEmpty &&
        !filter.aiTools.contains(film.aiToolName)) {
      return false;
    }
    final minutes = _averageMinutes(film.id);
    final inLength = switch (filter.length) {
      // The catalog gives no episode lengths, so it cannot be ruled out.
      _ when film.catalogDramaId != null => true,
      LengthFilter.any => true,
      LengthFilter.under5 => minutes < 5,
      LengthFilter.from5to15 => minutes >= 5 && minutes < 15,
      LengthFilter.from15to30 => minutes >= 15 && minutes <= 30,
    };
    if (!inLength) return false;
    final query = filter.query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      film.title,
      film.creatorName,
      film.promptCredit ?? '',
      film.synopsis ?? '',
    ].any((text) => text.toLowerCase().contains(query));
  }

  double _averageMinutes(int filmId) {
    final seconds = _episodes.values
        .where((e) => e.filmId == filmId)
        .map((e) => e.durationSec)
        .toList();
    if (seconds.isEmpty) return 0;
    return seconds.reduce((a, b) => a + b) / seconds.length / 60;
  }

  Iterable<Film> get _approved =>
      _films.values.where((f) => f.status == 'approved');

  @override
  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]) async {
    await _catalogLoading;
    return _approved.where((f) => _matches(f, filter)).toList();
  }

  @override
  Future<List<Film>> followingFilms(int userId) async =>
      _approved.where((f) => _follows.contains((userId, f.creatorId))).toList();

  @override
  Future<List<Episode>> episodes(int filmId) async {
    final list = _episodes.values.where((e) => e.filmId == filmId).toList();
    list.sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
    return list;
  }

  bool _isSubscribed(int userId) {
    final subscription = _subscriptions[userId];
    return subscription != null && subscription.endDate.isAfter(_now);
  }

  bool _hasUnlocked(int userId, int episodeId) =>
      _unlocks.any((u) => u.userId == userId && u.episodeId == episodeId);

  @override
  EpisodeAccess accessOf(int? userId, Episode episode) {
    if (episode.isFree) return EpisodeAccess.free;
    if (userId == null) return EpisodeAccess.locked;
    if (_films[episode.filmId]!.creatorId == userId) {
      return EpisodeAccess.unlocked;
    }
    if (_hasUnlocked(userId, episode.id)) return EpisodeAccess.unlocked;
    if (_isSubscribed(userId)) return EpisodeAccess.plus;
    return EpisodeAccess.locked;
  }

  @override
  List<FilmComment> commentsOf(int filmId) =>
      _comments.where((c) => _commentFilm[c.id] == filmId).toList();

  @override
  Future<void> addComment(
    int userId,
    int filmId,
    String body, {
    int? parentId,
  }) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw _error('VALIDATION_ERROR', 'Write a comment first.', 400);
    }
    if (parentId != null && _commentFilm[parentId] != filmId) {
      throw _error('NOT_FOUND', 'That comment is no longer there.', 404);
    }
    final id = _nextCommentId++;
    _comments.insert(
      0,
      FilmComment(
        id: id,
        userId: userId,
        username: _user(userId).username,
        body: text,
        parentId: parentId,
      ),
    );
    _commentFilm[id] = filmId;
    final film = _films[filmId]!;
    _films[filmId] = film.copyWith(commentCount: film.commentCount + 1);
    if (parentId == null) {
      _notify(
        film.creatorId,
        NotificationKind.comment,
        actorId: userId,
        filmId: filmId,
      );
    } else {
      final parent = _comments.firstWhere((c) => c.id == parentId);
      _notify(
        parent.userId,
        NotificationKind.reply,
        actorId: userId,
        filmId: filmId,
      );
    }
  }

  @override
  Future<void> removeComment(int commentId) async {
    final removed = {
      commentId,
      for (final c in _comments)
        if (c.parentId == commentId) c.id,
    };
    for (final id in removed) {
      final filmId = _commentFilm.remove(id);
      _comments.removeWhere((c) => c.id == id);
      _commentLikes.removeWhere((like) => like.$2 == id);
      if (filmId == null) continue;
      final film = _films[filmId]!;
      _films[filmId] = film.copyWith(commentCount: film.commentCount - 1);
    }
  }

  @override
  bool isCommentLiked(int userId, int commentId) =>
      _commentLikes.contains((userId, commentId));

  @override
  int commentLikeCount(int commentId) =>
      _commentLikes.where((like) => like.$2 == commentId).length;

  @override
  void toggleCommentLike(int userId, int commentId) {
    final like = (userId, commentId);
    if (!_commentLikes.remove(like)) _commentLikes.add(like);
  }

  @override
  Future<void> reportFilm(int userId, int filmId, String reason) async {
    _reports.add(
      FilmReport(
        id: _reports.length + 1,
        filmId: filmId,
        filmTitle: _films[filmId]!.title,
        reason: reason,
        isOpen: true,
      ),
    );
  }

  void _record(
    int userId,
    String type,
    int amount,
    int balanceAfter,
    String label,
  ) {
    final list = _transactions.putIfAbsent(userId, () => []);
    list.insert(
      0,
      Transaction(
        id: _transactions.values.fold(0, (sum, l) => sum + l.length) + 1,
        type: type,
        amount: amount,
        balanceAfter: balanceAfter,
        createdAt: _now,
        label: label,
      ),
    );
  }

  @override
  Future<User> unlock(int userId, int episodeId) async {
    final user = _user(userId);
    final episode = _episodes[episodeId]!;
    // Same rule as UNIQUE(user_id, episode_id): a repeat never charges twice.
    if (_hasUnlocked(userId, episodeId)) return user;
    if (user.coinBalance < episode.priceCoins) {
      throw _error('INSUFFICIENT_COINS', 'Not enough coins', 402);
    }
    final film = _films[episode.filmId]!;
    final ownedByAdmin = _user(film.creatorId).role == UserRole.admin;
    final adminShare = ownedByAdmin
        ? episode.priceCoins
        : episode.priceCoins * _adminSharePercent ~/ 100;
    final updated = user.copyWith(
      coinBalance: user.coinBalance - episode.priceCoins,
    );
    _users[userId] = updated;
    _unlocks.add(
      _Unlock(userId, episodeId, episode.priceCoins - adminShare, adminShare),
    );
    _record(
      userId,
      'unlock',
      -episode.priceCoins,
      updated.coinBalance,
      '${film.title}, Episode ${episode.episodeNo}',
    );
    _notify(
      film.creatorId,
      NotificationKind.unlock,
      actorId: userId,
      filmId: film.id,
      episodeNo: episode.episodeNo,
    );
    return updated;
  }

  @override
  Future<User> demoTopUp(int userId) => _topUp(userId, demoTopUpCoins);

  @override
  Future<User> topUpPack(int userId, CoinPack pack) =>
      _topUp(userId, pack.coins, priceUsd: pack.priceUsd);

  Future<User> _topUp(int userId, int coins, {double priceUsd = 0}) async {
    final updated = _user(
      userId,
    ).copyWith(coinBalance: _user(userId).coinBalance + coins);
    _users[userId] = updated;
    _salesUsd += priceUsd;
    _record(userId, 'topup', coins, updated.coinBalance, 'Demo top-up');
    return updated;
  }

  @override
  Future<Subscription> subscribe(int userId) async {
    final subscription = Subscription(
      id: _subscriptions.length + 1,
      priceUsd: _subscriptionPrice,
      startDate: _now,
      endDate: _now.add(const Duration(days: 30)),
    );
    _subscriptions[userId] = subscription;
    _salesUsd += _subscriptionPrice;
    return subscription;
  }

  @override
  Future<Subscription?> subscriptionOf(int userId) async =>
      _isSubscribed(userId) ? _subscriptions[userId] : null;

  @override
  Future<void> cancelSubscription(int userId) async {
    final plan = _subscriptions[userId]!;
    _subscriptions[userId] = Subscription(
      id: plan.id,
      priceUsd: plan.priceUsd,
      startDate: plan.startDate,
      endDate: plan.endDate,
      isCancelled: true,
    );
  }

  @override
  double get subscriptionPriceUsd => _subscriptionPrice;

  @override
  int get episodePriceCoins => _episodePrice;

  @override
  Future<List<Transaction>> transactionsOf(int userId) async =>
      List.unmodifiable(_transactions[userId] ?? const []);

  @override
  Future<List<CoinPack>> coinPacks() async => mockCoinPacks;

  @override
  int get demoTopUpCoins => 100;

  @override
  bool isLiked(int userId, int filmId) => _likes.contains((userId, filmId));

  @override
  bool isSaved(int userId, int filmId) => _saved.contains((userId, filmId));

  @override
  bool isFollowing(int userId, int creatorId) =>
      _follows.contains((userId, creatorId));

  @override
  Future<void> toggleLike(int userId, int filmId) async {
    final film = _films[filmId]!;
    final added = _likes.add((userId, filmId));
    if (!added) _likes.remove((userId, filmId));
    _films[filmId] = film.copyWith(
      likeCount: film.likeCount + (added ? 1 : -1),
    );
    if (added) {
      _notify(
        film.creatorId,
        NotificationKind.like,
        actorId: userId,
        filmId: filmId,
      );
    }
  }

  @override
  Future<void> toggleSave(int userId, int filmId) async {
    if (!_saved.add((userId, filmId))) _saved.remove((userId, filmId));
  }

  @override
  Future<void> toggleFollow(int userId, int creatorId) async {
    if (_follows.add((userId, creatorId))) {
      _notify(creatorId, NotificationKind.follow, actorId: userId);
    } else {
      _follows.remove((userId, creatorId));
    }
  }

  @override
  Future<void> refreshLibrary(int userId) async {}

  @override
  Future<void> loadComments(int filmId) async {}

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearSession() async {}

  @override
  bool get playsVideo => false;

  @override
  Future<Playback> playback(int episodeId) async =>
      Playback(episode: _episodes[episodeId]!, streamUrl: null);

  @override
  List<Film> watchlistOf(int userId) =>
      _approved.where((f) => _saved.contains((userId, f.id))).toList();

  @override
  List<Film> unlockedFilmsOf(int userId) {
    final filmIds = _unlocks
        .where((u) => u.userId == userId)
        .map((u) => _episodes[u.episodeId]!.filmId)
        .toSet();
    return filmIds.map((id) => _films[id]!).toList();
  }

  @override
  void recordProgress(int userId, int filmId, int episodeNo) {
    final list = _progress.putIfAbsent(userId, () => []);
    list.removeWhere((entry) => entry.$1 == filmId);
    list.insert(0, (filmId, episodeNo));
  }

  @override
  List<WatchProgress> continueWatching(int userId) {
    final entries = [...?_progress[userId]];
    final seen = {for (final entry in entries) entry.$1};

    // Episodes someone unlocked count as watching, even before they play one.
    final furthest = <int, int>{};
    for (final unlock in _unlocks.where((u) => u.userId == userId)) {
      final episode = _episodes[unlock.episodeId]!;
      final current = furthest[episode.filmId] ?? 0;
      if (episode.episodeNo > current) {
        furthest[episode.filmId] = episode.episodeNo;
      }
    }
    for (final entry in furthest.entries) {
      if (!seen.contains(entry.key)) entries.add((entry.key, entry.value));
    }

    return [
      for (final (filmId, episodeNo) in entries)
        if (_films[filmId] case final film?
            when film.status == 'approved' && episodeNo < film.episodeCount)
          WatchProgress(film: film, episodeNo: episodeNo),
    ];
  }

  @override
  List<User> followingOf(int userId) =>
      _follows.where((f) => f.$1 == userId).map((f) => _user(f.$2)).toList();

  @override
  int followerCount(int userId) => _follows.where((f) => f.$2 == userId).length;

  @override
  Future<Film> upload({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<EpisodeDraft> episodes,
  }) async {
    final episodePrices = [for (final e in episodes) e.priceCoins];
    final id = _films.keys.reduce((a, b) => a > b ? a : b) + 1;
    final film = Film(
      id: id,
      creatorId: creatorId,
      title: title,
      synopsis: null,
      posterUrl: null,
      genreId: mockGenres.indexOf(genre) + 1,
      aiToolId: mockAiTools.indexOf(aiTool) + 1,
      promptCredit: promptCredit,
      isAiGenerated: true,
      status: 'pending',
      creatorName: _user(creatorId).username,
      genreName: genre,
      aiToolName: aiTool,
      episodeCount: episodePrices.length,
    );
    _films[id] = film;
    for (var i = 0; i < episodePrices.length; i++) {
      _addEpisode(id, i + 1, price: episodePrices[i]);
    }
    return film;
  }

  @override
  Future<void> updateFilm(
    int filmId, {
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
  }) async {
    final film = _films[filmId]!;
    final resubmitted = film.status == 'rejected';
    _films[filmId] = film.copyWith(
      title: title,
      genreId: mockGenres.indexOf(genre) + 1,
      genreName: genre,
      aiToolId: mockAiTools.indexOf(aiTool) + 1,
      aiToolName: aiTool,
      promptCredit: promptCredit,
      status: resubmitted ? 'pending' : null,
      clearReviewNote: resubmitted,
    );
  }

  @override
  Future<void> deleteFilm(int filmId) async {
    // Viewers keep what they paid for, so sold films stay until taken down.
    final episodeIds = _episodes.values
        .where((e) => e.filmId == filmId)
        .map((e) => e.id)
        .toSet();
    if (_unlocks.any((u) => episodeIds.contains(u.episodeId))) {
      throw _error(
        'CONFLICT',
        'This film has paid unlocks, so it cannot be deleted.',
        409,
      );
    }
    _episodes.removeWhere((id, _) => episodeIds.contains(id));
    _films.remove(filmId);
  }

  @override
  Future<void> setEpisodePrices(Map<int, int> pricesByEpisodeId) async {
    pricesByEpisodeId.forEach((episodeId, coins) {
      final episode = _episodes[episodeId];
      if (episode == null) return;
      if (coins < 0 || coins > 999) {
        throw _error('VALIDATION', 'A price must be 0 to 999 coins.', 400);
      }
      _episodes[episodeId] = episode.withPrice(coins);
    });
  }

  @override
  Future<EpisodePricing> pricingOf(int filmId) async {
    final episodes = _episodes.values.where((e) => e.filmId == filmId);
    final paid = episodes.where((e) => !e.isFree);
    return EpisodePricing(
      freeCount: episodes.length - paid.length,
      paidCount: paid.length,
      priceCoins: paid.isEmpty
          ? 0
          : paid.map((e) => e.priceCoins).reduce((a, b) => a < b ? a : b),
      maxPriceCoins: paid.isEmpty
          ? 0
          : paid.map((e) => e.priceCoins).reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  Future<List<Film>> filmsOf(int creatorId) async => _ownFilms(creatorId);

  List<Film> _ownFilms(int creatorId) =>
      _films.values.where((f) => f.creatorId == creatorId).toList();

  @override
  List<DailyStat> dailyStatsOf(int creatorId, {int days = 60}) {
    final totals = _earnings(creatorId);
    final views = _spread(totals.views, days, creatorId, 1);
    final likes = _spread(totals.likes, days, creatorId, 2);
    final coins = _spread(totals.coins, days, creatorId, 3);
    final today = DateTime(_now.year, _now.month, _now.day);
    return [
      for (var i = 0; i < days; i++)
        DailyStat(
          day: today.subtract(Duration(days: days - 1 - i)),
          views: views[i],
          likes: likes[i],
          coins: coins[i],
        ),
    ];
  }

  /// Spreads a lifetime [total] over [days] days with a rising, uneven shape,
  /// so the same channel always draws the same chart.
  List<int> _spread(int total, int days, int seed, int channel) {
    if (total <= 0 || days <= 0) return List.filled(days, 0);
    final weights = [
      for (var i = 0; i < days; i++)
        (0.25 + (1 + math.sin(i * 0.75 + seed * 1.7 + channel)) / 2) *
            (0.6 + 0.8 * i / math.max(days - 1, 1)),
    ];
    final sum = weights.fold(0.0, (a, b) => a + b);
    final exact = [for (final w in weights) total * w / sum];
    final parts = [for (final x in exact) x.floor()];
    // Largest remainder: the days that lost the most to rounding get the
    // leftovers, so small totals still look uneven rather than flat.
    var left = total - parts.fold(0, (a, b) => a + b);
    final byRemainder = [for (var i = 0; i < days; i++) i]
      ..sort((a, b) => (exact[b] - parts[b]).compareTo(exact[a] - parts[a]));
    for (var k = 0; left > 0; k = (k + 1) % days) {
      parts[byRemainder[k]]++;
      left--;
    }
    return parts;
  }

  @override
  Future<Earnings> earningsOf(int creatorId) async => _earnings(creatorId);

  Earnings _earnings(int creatorId) {
    final films = _ownFilms(creatorId);
    final filmIds = films.map((f) => f.id).toSet();
    final unlocks = _unlocks.where(
      (u) => filmIds.contains(_episodes[u.episodeId]!.filmId),
    );
    return Earnings(
      coins: unlocks.fold(0, (sum, u) => sum + u.creatorShare),
      unlocks: unlocks.length,
      views: films.fold(0, (sum, f) => sum + f.viewCount),
      likes: films.fold(0, (sum, f) => sum + f.likeCount),
      adminSharePercent: _adminSharePercent,
      coinsByFilm: {
        for (final film in films)
          film.id: _unlocks
              .where((u) => _episodes[u.episodeId]!.filmId == film.id)
              .fold(0, (sum, u) => sum + u.creatorShare),
      },
    );
  }

  @override
  Future<List<Film>> reviewQueue() async =>
      _films.values.where((f) => f.status == 'pending').toList();

  @override
  Future<List<Film>> liveFilms() async => _approved.toList();

  @override
  Future<void> review(int filmId, String status, {String? note}) async {
    final film = _films[filmId]!;
    _films[filmId] = film.copyWith(status: status, reviewNote: note);
    final kind = switch (status) {
      'approved' => NotificationKind.approved,
      'rejected' => NotificationKind.rejected,
      'taken_down' => NotificationKind.takenDown,
      _ => null,
    };
    if (kind != null && film.status != status) {
      _notify(film.creatorId, kind, filmId: filmId);
    }
    if (status == 'taken_down') {
      final open = _reports.where((r) => r.isOpen && r.filmId == filmId);
      for (final report in open.toList()) {
        await resolveReport(report.id);
      }
    }
  }

  @override
  Future<List<FilmReport>> openReports() async =>
      _reports.where((r) => r.isOpen).toList();

  @override
  Future<void> resolveReport(int reportId) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    final report = _reports[index];
    _reports[index] = FilmReport(
      id: report.id,
      filmId: report.filmId,
      filmTitle: report.filmTitle,
      reason: report.reason,
      isOpen: false,
    );
  }

  @override
  Future<AdminSales> adminSales() async => AdminSales(
    totalUsd: _salesUsd,
    adminCoins: _unlocks.fold(0, (sum, u) => sum + u.adminShare),
    coinsSpent: _unlocks.fold(0, (sum, u) => sum + u.coinsSpent),
    creatorCoins: _unlocks.fold(0, (sum, u) => sum + u.creatorShare),
    unlockCount: _unlocks.length,
  );

  @override
  Future<int> adminSharePercent() async => _adminSharePercent;

  @override
  Future<void> setAdminSharePercent(int percent) async =>
      _adminSharePercent = percent;
}

class _Unlock {
  const _Unlock(
    this.userId,
    this.episodeId,
    this.creatorShare,
    this.adminShare,
  );

  final int userId;
  final int episodeId;
  final int creatorShare;
  final int adminShare;
  int get coinsSpent => creatorShare + adminShare;
}
