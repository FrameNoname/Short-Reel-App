import 'dart:convert';

import 'package:shortreel/models/coin_pack.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/data/app_repository.dart';
import 'mock_catalog_data.dart';
import 'mock_data.dart';

/// Answers every screen from the demo data in mock_data.dart, in memory.
/// Nothing is sent to the backend; changes last until the app is closed.
///
/// The Series Jeen catalog comes from the snapshot in mock_catalog_data.dart
/// and follows the same rules as the backend: the first episodes are free,
/// a later one costs coins once, and the admin can take a series down.
class MockRepository implements AppRepository {
  MockRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    for (final film in _films.values) {
      for (var n = 1; n <= film.episodeCount; n++) {
        _addEpisode(film.id, n, price: n <= 2 ? 0 : _episodePrice);
      }
    }
    _seedUnlocks();
    _seedWallets();
    // The feed shows the first catalog series after the app's own films.
    _catalogFeed = [
      for (final d in _allDramas.where((d) => d.posterUrl != null).take(12))
        catalogFilm(d).id,
    ];
  }

  static const _episodePrice = 20;

  /// Short demo clips bundled with the app (see pubspec.yaml).
  static const _clips = [
    'assets/videos/clip_01.mp4',
    'assets/videos/clip_02.mp4',
    'assets/videos/clip_03.mp4',
  ];

  /// The bundled clip that stands in for episode [episodeNo].
  static String clipFor(int episodeNo) =>
      _clips[(episodeNo - 1) % _clips.length];

  // ---- Series Jeen catalog ------------------------------------------------

  final List<CatalogDrama> _allDramas = [
    for (final d in jsonDecode(mockCatalogJson) as List)
      CatalogDrama.fromJson(d as Map<String, dynamic>),
  ];

  /// Drama ids the admin took down.
  final Set<int> _takenDown = {};

  /// Catalog episodes each viewer paid for: (user, drama, episode number).
  final Set<(int, int, int)> _catalogUnlocked = {};

  /// Film ids of the catalog series in the feed, in order.
  List<int> _catalogFeed = const [];

  /// The series viewers can see; taken-down ones are left out.
  List<CatalogDrama> get catalogDramas => [
    for (final d in _allDramas)
      if (!_takenDown.contains(d.id)) d,
  ];

  bool _isCatalog(int filmId) => filmId >= catalogFilmIdBase;

  /// Catalog episode ids are film id * 1000 + episode number, as in the app.
  int _filmOf(int episodeId) => episodeId >= catalogFilmIdBase * 1000
      ? episodeId ~/ 1000
      : _episodes[episodeId]!.filmId;

  bool _catalogOpen(int? userId, int dramaId, int episodeNo) =>
      episodeNo <= _settings.catalogFreeEpisodes ||
      _isAdmin(userId) ||
      (userId != null &&
          _catalogUnlocked.contains((userId, dramaId, episodeNo)));

  List<Episode> _catalogEpisodes(int filmId) {
    final film = _films[filmId];
    final dramaId = filmId - catalogFilmIdBase;
    final free = _settings.catalogFreeEpisodes;
    return [
      for (var n = 1; n <= (film?.episodeCount ?? 0); n++)
        Episode(
          id: filmId * 1000 + n,
          filmId: filmId,
          episodeNo: n,
          title: 'Episode $n',
          durationSec: 0,
          isFree: n <= free,
          priceCoins: n <= free ? 0 : _settings.catalogPriceCoins,
          access: n <= free
              ? EpisodeAccess.free
              : _catalogOpen(_currentUserId, dramaId, n)
              ? EpisodeAccess.unlocked
              : EpisodeAccess.locked,
        ),
    ];
  }

  final DateTime _now;
  final Map<int, User> _users = {for (final u in mockUsers) u.id: u};
  final Map<String, String> _passwords = Map.of(mockPasswords);
  final Map<int, Film> _films = {for (final f in mockFilms) f.id: f};
  final Map<int, Episode> _episodes = {};
  final Map<int, List<Transaction>> _transactions = {};
  final List<_Unlock> _unlocks = [];
  final Set<(int, int)> _likes = {(2, 1), (3, 3)};
  final Set<(int, int)> _saved = {(2, 2), (2, 3), (3, 1)};

  final List<FilmComment> _comments = [
    const FilmComment(
      id: 1,
      userId: 3,
      username: 'viewer01',
      body: 'The ending of episode 2 was great!',
    ),
    const FilmComment(
      id: 2,
      userId: 2,
      username: 'mira.lens',
      body: 'Love the paper-cut style.',
    ),
  ];
  final Map<int, int> _commentFilm = {1: 1, 2: 2};
  late final Map<int, DateTime> _commentTime = {
    1: _now.subtract(const Duration(hours: 5)),
    2: _now.subtract(const Duration(days: 1)),
  };
  int _nextCommentId = 3;

  // What the admin can change: the packs on sale and the demo top-up.
  final List<CoinPack> _packs = List.of(mockCoinPacks);
  final Map<int, int> _packSold = {1: 1};
  int _nextPackId = mockCoinPacks.length + 1;
  AdminSettings _settings = const AdminSettings();

  double _salesUsd = 0.99;
  int _nextEpisodeId = 1;

  /// Who is signed in, so [playback] can answer like the server would.
  int? _currentUserId;

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

  @override
  Film catalogFilm(CatalogDrama drama) {
    final id = catalogFilmIdBase + drama.id;
    return _films[id] ??= Film(
      id: id,
      title: drama.title,
      synopsis: drama.description,
      posterUrl: drama.posterUrl,
      genreId: 0,
      aiToolId: 0,
      promptCredit: null,
      // Nothing confirms how these were made, so they carry no AI label.
      isAiGenerated: false,
      status: _takenDown.contains(drama.id) ? 'taken_down' : 'approved',
      genreName: drama.genres.isEmpty ? '' : drama.genres.first,
      genreTags: drama.genres,
      episodeCount: drama.episodeCount,
      catalogDramaId: drama.id,
    );
  }

  @override
  Film? filmById(int id) => _films[id];

  void _seedUnlocks() {
    void seed(int userId, int filmId, int number) {
      final episode = _episodes.values.firstWhere(
        (e) => e.filmId == filmId && e.episodeNo == number,
      );
      _unlocks.add(_Unlock(userId, episode.id, _episodePrice));
    }

    seed(2, 1, 3);
    seed(2, 1, 4);
    seed(3, 3, 3);
    seed(2, 5, 3);
  }

  void _seedWallets() {
    DateTime daysAgo(int days) => _now.subtract(Duration(days: days));

    // Newest first, adding up to the balances in mock_data.dart.
    _transactions[2] = [
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
    _transactions[3] = [
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
  }

  ApiException _error(String code, String message, int status) =>
      ApiException(code: code, message: message, statusCode: status);

  User _user(int id) => _users[id]!;

  bool _isAdmin(int? userId) =>
      userId != null && _users[userId]?.role == UserRole.admin;

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
    final user = _users.values.firstWhere((u) => u.username == name);
    _currentUserId = user.id;
    return user;
  }

  /// Everyone who signs up is a viewer.
  @override
  Future<User> register(String username, String password) async {
    final name = username.trim();
    if (_passwords.containsKey(name)) {
      throw _error('CONFLICT', 'This username is already taken.', 409);
    }
    final id = _users.keys.reduce((a, b) => a > b ? a : b) + 1;
    final user = User(
      id: id,
      username: name,
      displayName: name,
      role: UserRole.viewer,
      coinBalance: 0,
    );
    _users[id] = user;
    _passwords[name] = password;
    _currentUserId = id;
    return user;
  }

  bool _matches(Film film, String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return film.title.toLowerCase().contains(text);
  }

  Iterable<Film> get _approved =>
      _films.values.where((f) => f.status == 'approved');

  /// The app's own films, then the catalog series in the feed, as on the API.
  @override
  Future<List<Film>> films([String query = '']) async => [
    ..._approved.where((f) => !_isCatalog(f.id) && _matches(f, query)),
    for (final id in _catalogFeed)
      if (_films[id]!.status == 'approved' && _matches(_films[id]!, query))
        _films[id]!,
  ];

  @override
  Future<List<Episode>> episodes(int filmId) async {
    if (_isCatalog(filmId)) return _catalogEpisodes(filmId);
    final list = _episodes.values.where((e) => e.filmId == filmId).toList();
    list.sort((a, b) => a.episodeNo.compareTo(b.episodeNo));
    return list;
  }

  bool _hasUnlocked(int userId, int episodeId) =>
      _unlocks.any((u) => u.userId == userId && u.episodeId == episodeId);

  /// The admin runs the catalogue and may watch every episode.
  @override
  EpisodeAccess accessOf(int? userId, Episode episode) {
    if (episode.access != null) return episode.access!;
    if (episode.isFree) return EpisodeAccess.free;
    if (userId == null) return EpisodeAccess.locked;
    if (_isAdmin(userId)) return EpisodeAccess.unlocked;
    if (_hasUnlocked(userId, episode.id)) return EpisodeAccess.unlocked;
    return EpisodeAccess.locked;
  }

  @override
  List<FilmComment> commentsOf(int filmId) =>
      _comments.where((c) => _commentFilm[c.id] == filmId).toList();

  @override
  Future<void> addComment(int userId, int filmId, String body) async {
    if (_isCatalog(filmId)) {
      throw _error(
        'NOT_SUPPORTED',
        'Comments are not available for catalog series.',
        400,
      );
    }
    final text = body.trim();
    if (text.isEmpty) {
      throw _error('VALIDATION_ERROR', 'Write a comment first.', 400);
    }
    final id = _nextCommentId++;
    _comments.insert(
      0,
      FilmComment(
        id: id,
        userId: userId,
        username: _user(userId).username,
        body: text,
      ),
    );
    _commentFilm[id] = filmId;
    _commentTime[id] = DateTime.now();
    final film = _films[filmId]!;
    _films[filmId] = film.copyWith(commentCount: film.commentCount + 1);
  }

  @override
  Future<void> removeComment(int commentId) async {
    final filmId = _commentFilm.remove(commentId);
    _comments.removeWhere((c) => c.id == commentId);
    if (filmId == null) return;
    final film = _films[filmId]!;
    _films[filmId] = film.copyWith(commentCount: film.commentCount - 1);
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
    if (episodeId >= catalogFilmIdBase * 1000) {
      return _unlockCatalog(userId, episodeId);
    }
    final user = _user(userId);
    final episode = _episodes[episodeId]!;
    // Same rule as UNIQUE(user_id, episode_id): a repeat never charges twice.
    if (_isAdmin(userId) || _hasUnlocked(userId, episodeId)) return user;
    if (user.coinBalance < episode.priceCoins) {
      throw _error('INSUFFICIENT_COINS', 'Not enough coins', 402);
    }
    final film = _films[episode.filmId]!;
    final updated = user.copyWith(
      coinBalance: user.coinBalance - episode.priceCoins,
    );
    _users[userId] = updated;
    _unlocks.add(_Unlock(userId, episodeId, episode.priceCoins));
    _record(
      userId,
      'unlock',
      -episode.priceCoins,
      updated.coinBalance,
      '${film.title}, Episode ${episode.episodeNo}',
    );
    return updated;
  }

  /// A paid catalog episode, charged once at the catalog price.
  Future<User> _unlockCatalog(int userId, int episodeId) async {
    final user = _user(userId);
    final filmId = episodeId ~/ 1000;
    final episodeNo = episodeId % 1000;
    final dramaId = filmId - catalogFilmIdBase;
    if (_catalogOpen(userId, dramaId, episodeNo)) return user;
    final price = _settings.catalogPriceCoins;
    if (user.coinBalance < price) {
      throw _error('INSUFFICIENT_COINS', 'Not enough coins', 402);
    }
    final updated = user.copyWith(coinBalance: user.coinBalance - price);
    _users[userId] = updated;
    _catalogUnlocked.add((userId, dramaId, episodeNo));
    _unlocks.add(_Unlock(userId, episodeId, price));
    _record(
      userId,
      'unlock',
      -price,
      updated.coinBalance,
      '${_films[filmId]!.title}, Episode $episodeNo',
    );
    return updated;
  }

  @override
  Future<User> refreshBalance(int userId) async => _user(userId);

  @override
  Future<User> demoTopUp(int userId) => _topUp(userId, demoTopUpCoins);

  @override
  Future<User> topUpPack(int userId, CoinPack pack) {
    _packSold[pack.id] = (_packSold[pack.id] ?? 0) + 1;
    return _topUp(userId, pack.coins, priceUsd: pack.priceUsd);
  }

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
  int get episodePriceCoins => _episodePrice;

  @override
  Future<List<Transaction>> transactionsOf(int userId) async =>
      List.unmodifiable(_transactions[userId] ?? const []);

  @override
  Future<List<CoinPack>> coinPacks() async =>
      List.unmodifiable([..._packs]..sort((a, b) => a.coins - b.coins));

  @override
  int get demoTopUpCoins => _settings.demoTopUpCoins;

  @override
  bool isLiked(int userId, int filmId) => _likes.contains((userId, filmId));

  @override
  bool isSaved(int userId, int filmId) => _saved.contains((userId, filmId));

  @override
  Future<void> toggleLike(int userId, int filmId) async {
    final film = _films[filmId]!;
    final added = _likes.add((userId, filmId));
    if (!added) _likes.remove((userId, filmId));
    _films[filmId] = film.copyWith(
      likeCount: film.likeCount + (added ? 1 : -1),
    );
  }

  @override
  Future<void> toggleSave(int userId, int filmId) async {
    if (!_saved.add((userId, filmId))) _saved.remove((userId, filmId));
  }

  @override
  Future<void> refreshLibrary(int userId) async {}

  @override
  Future<void> loadComments(int filmId) async {}

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<void> logout() async => _currentUserId = null;

  @override
  Future<void> clearSession() async => _currentUserId = null;

  @override
  bool get playsVideo => true;

  /// Plays one of the bundled clips when the viewer may watch the episode.
  /// The `asset:` prefix tells the player to read it from the app bundle.
  @override
  Future<Playback> playback(int episodeId) async {
    final episode = _episodes[episodeId]!;
    final allowed = accessOf(_currentUserId, episode) != EpisodeAccess.locked;
    return Playback(
      episode: episode,
      streamUrl: allowed ? 'asset:${clipFor(episode.episodeNo)}' : null,
    );
  }

  @override
  List<Film> watchlistOf(int userId) =>
      _approved.where((f) => _saved.contains((userId, f.id))).toList();

  @override
  List<Film> unlockedFilmsOf(int userId) {
    final filmIds = _unlocks
        .where((u) => u.userId == userId)
        .map((u) => _filmOf(u.episodeId))
        .toSet();
    return filmIds.map((id) => _films[id]!).toList();
  }

  @override
  bool catalogEpisodeLocked(Film film, int episodeNo) {
    final dramaId = film.catalogDramaId;
    return dramaId != null && !_catalogOpen(_currentUserId, dramaId, episodeNo);
  }

  @override
  Future<AdminSales> adminSales() async {
    final perFilm = <int, (int, int)>{};
    for (final u in _unlocks) {
      final filmId = _filmOf(u.episodeId);
      final (count, coins) = perFilm[filmId] ?? (0, 0);
      perFilm[filmId] = (count + 1, coins + u.coinsSpent);
    }
    final rows = [
      for (final MapEntry(key: id, value: (count, coins)) in perFilm.entries)
        FilmSales(
          filmId: id,
          title: _films[id]!.title,
          unlockCount: count,
          coinsSpent: coins,
        ),
    ]..sort((a, b) => b.coinsSpent.compareTo(a.coinsSpent));
    return AdminSales(
      totalUsd: _salesUsd,
      coinsSpent: _unlocks.fold(0, (sum, u) => sum + u.coinsSpent),
      unlockCount: _unlocks.length,
      perFilm: rows,
    );
  }

  // ---- admin: films, comments, settings and coin packs ----------------------

  /// A catalog series gets an admin row once someone bought an episode or
  /// the admin took it down, as on the server.
  bool _hasAdminRow(Film film) {
    final dramaId = film.catalogDramaId;
    if (dramaId == null) return true;
    return _takenDown.contains(dramaId) ||
        _unlocks.any((u) => _filmOf(u.episodeId) == film.id);
  }

  AdminFilm _adminFilm(Film f, {bool listed = true}) => AdminFilm(
    id: listed ? f.id : 0,
    title: f.title,
    posterUrl: f.posterUrl,
    takenDown: f.status == 'taken_down',
    episodeCount: _isCatalog(f.id)
        ? f.episodeCount
        : _episodes.values.where((e) => e.filmId == f.id).length,
    likeCount: f.likeCount,
    commentCount: f.commentCount,
    coinsSpent: _unlocks
        .where((u) => _filmOf(u.episodeId) == f.id)
        .fold(0, (sum, u) => sum + u.coinsSpent),
    catalogDramaId: f.catalogDramaId,
  );

  /// Series Jeen series first, then the app's own films, newest first.
  @override
  Future<List<AdminFilm>> adminFilms() async {
    final rows = _films.values.where(_hasAdminRow).toList()
      ..sort((a, b) {
        final kind = (a.catalogDramaId == null ? 1 : 0).compareTo(
          b.catalogDramaId == null ? 1 : 0,
        );
        return kind != 0 ? kind : b.id.compareTo(a.id);
      });
    return [for (final f in rows) _adminFilm(f)];
  }

  @override
  Future<void> adminSetFilmTakenDown(AdminFilm admin, bool takenDown) async {
    final dramaId = admin.catalogDramaId;
    if (dramaId != null) {
      final drama = _allDramas.where((d) => d.id == dramaId).firstOrNull;
      if (drama == null) throw _error('NOT_FOUND', 'Series not found', 404);
      takenDown ? _takenDown.add(dramaId) : _takenDown.remove(dramaId);
      final film = catalogFilm(drama);
      _films[film.id] = film.copyWith(
        status: takenDown ? 'taken_down' : 'approved',
      );
      return;
    }
    final film = _films[admin.id];
    if (film == null) throw _error('NOT_FOUND', 'Film not found', 404);
    _films[admin.id] = film.copyWith(
      status: takenDown ? 'taken_down' : 'approved',
    );
  }

  /// Up to 30 series whose title matches, taken-down ones included.
  @override
  Future<List<AdminFilm>> adminSearchCatalog(String query) async {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return const [];
    return [
      for (final d
          in _allDramas
              .where((d) => d.title.toLowerCase().contains(text))
              .take(30))
        _adminSearchRow(d),
    ];
  }

  AdminFilm _adminSearchRow(CatalogDrama drama) {
    final id = catalogFilmIdBase + drama.id;
    final known = _films[id];
    final film = known ?? catalogFilm(drama);
    final row = _adminFilm(film, listed: _hasAdminRow(film));
    // Looking a series up does not add it to the app.
    if (known == null) _films.remove(id);
    return row;
  }

  @override
  Future<List<AdminEpisode>> adminEpisodes(int filmId) async => [
    for (final e in await episodes(filmId))
      AdminEpisode(
        id: e.id,
        episodeNo: e.episodeNo,
        title: e.title,
        isFree: e.isFree,
        priceCoins: e.priceCoins,
        unlockCount: _unlocks.where((u) => u.episodeId == e.id).length,
      ),
  ];

  @override
  Future<AdminEpisode> adminUpdateEpisode(
    AdminEpisode episode, {
    required bool isFree,
    required int priceCoins,
  }) async {
    final price = isFree ? 0 : priceCoins;
    if (!isFree && price < 1) {
      throw _error(
        'VALIDATION_ERROR',
        'A paid episode needs a price of at least 1 coin',
        400,
      );
    }
    _episodes[episode.id] = _episodes[episode.id]!.withPrice(price);
    return episode.copyWith(isFree: isFree, priceCoins: price);
  }

  @override
  Future<AdminCommentPage> adminComments({
    int? filmId,
    int offset = 0,
    int limit = 20,
  }) async {
    final all =
        [
          for (final c in _comments)
            if (filmId == null || _commentFilm[c.id] == filmId)
              AdminComment(
                id: c.id,
                body: c.body,
                username: c.username,
                filmId: _commentFilm[c.id] ?? 0,
                filmTitle: _films[_commentFilm[c.id]]?.title ?? '',
                createdAt: _commentTime[c.id] ?? _now,
              ),
        ]..sort((a, b) {
          // Newest first; the demo comments' ids do not follow their times.
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });
    return AdminCommentPage(
      comments: all.skip(offset).take(limit).toList(),
      hasMore: all.length > offset + limit,
    );
  }

  @override
  Future<void> adminDeleteComment(int commentId) => removeComment(commentId);

  @override
  Future<AdminSettings> adminSettings() async => _settings;

  @override
  Future<AdminSettings> adminSaveSettings(AdminSettings settings) async {
    _settings = settings;
    return settings;
  }

  @override
  Future<List<AdminCoinPack>> adminCoinPacks() async => [
    for (final p in await coinPacks())
      AdminCoinPack(
        id: p.id,
        name: p.name,
        coins: p.coins,
        priceUsd: p.priceUsd,
        soldCount: _packSold[p.id] ?? 0,
      ),
  ];

  @override
  Future<void> adminSaveCoinPack({
    int? id,
    required String name,
    required int coins,
    required double priceUsd,
  }) async {
    final pack = CoinPack(
      id: id ?? _nextPackId++,
      name: name,
      coins: coins,
      priceUsd: priceUsd,
    );
    final index = _packs.indexWhere((p) => p.id == id);
    if (id != null && index < 0) {
      throw _error('NOT_FOUND', 'Coin pack not found', 404);
    }
    if (index < 0) {
      _packs.add(pack);
    } else {
      _packs[index] = pack;
    }
  }

  /// A pack that was already bought stays, as on the server.
  @override
  Future<void> adminDeleteCoinPack(int id) async {
    if ((_packSold[id] ?? 0) > 0) {
      throw _error(
        'IN_USE',
        'This pack was already bought and cannot be deleted',
        409,
      );
    }
    _packs.removeWhere((p) => p.id == id);
  }
}

class _Unlock {
  const _Unlock(this.userId, this.episodeId, this.coinsSpent);

  final int userId;
  final int episodeId;
  final int coinsSpent;
}
