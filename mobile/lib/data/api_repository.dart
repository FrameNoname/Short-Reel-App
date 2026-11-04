import '../models/catalog.dart';
import '../models/coin_pack.dart';
import '../models/episode.dart';
import '../models/film.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/token_store.dart';
import 'app_repository.dart';

/// The real thing: every core call goes to the REST API and MySQL behind it.
///
/// Small caches (films, like and save flags) let the screens read
/// synchronously what the last request returned.
class ApiRepository implements AppRepository {
  ApiRepository({
    required ApiClient client,
    required this._tokens,
    String? origin,
  }) : _api = client,
       _origin = origin ?? apiOrigin;

  /// Catalog series get ids from here up, so they never collide with real ids.
  static const catalogFilmIdBase = 100000000;

  static const _typicalEpisodePrice = 20;

  final ApiClient _api;
  final TokenStore _tokens;
  final String _origin;

  User? _me;
  int _demoCoins = 100;

  final Map<int, Film> _films = {};
  final Set<int> _liked = {};
  final Set<int> _saved = {};
  final Set<int> _unlockedFilmIds = {};
  final Map<int, int> _episodeFilm = {};
  List<int> _watchlistIds = const [];
  final Map<int, List<FilmComment>> _comments = {};

  List<Film> _catalogFilms = const [];
  Future<void>? _catalogLoading;

  // ---- session ----------------------------------------------------------

  User _userFrom(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    _me = user;
    return user;
  }

  @override
  Future<User> login(String username, String password) async {
    final json =
        await _api.post(
              '/auth/login',
              data: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    await _tokens.write(json['token'] as String);
    _api.beginNewSession();
    return _userFrom(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<User> register(String username, String password) async {
    final json =
        await _api.post(
              '/auth/register',
              data: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;
    await _tokens.write(json['token'] as String);
    _api.beginNewSession();
    return _userFrom(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<User?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      final json = await _api.get('/auth/me') as Map<String, dynamic>;
      return _userFrom(json['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      // A rejected token is useless; a network error keeps it for next time.
      if (e.statusCode == 401) await _tokens.clear();
      if (e.statusCode == 401) return null;
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (_me != null) await _api.post('/auth/logout');
    } on ApiException {
      // Logging out never depends on the server answering.
    }
    await clearSession();
  }

  @override
  Future<void> clearSession() async {
    // First, so answers still on their way for the old person are dropped.
    _api.beginNewSession();
    await _tokens.clear();
    _me = null;
    _liked.clear();
    _saved.clear();
    _unlockedFilmIds.clear();
    _watchlistIds = const [];
    _comments.clear();
  }

  @override
  Future<User> updateProfile(
    int userId, {
    required String displayName,
    required String bio,
  }) async {
    final json =
        await _api.put(
              '/auth/me',
              data: {'display_name': displayName, 'bio': bio},
            )
            as Map<String, dynamic>;
    return _userFrom(json['user'] as Map<String, dynamic>);
  }

  // ---- films ------------------------------------------------------------

  Film _remember(Map<String, dynamic> json) {
    final film = Film.fromJson(json);
    _films[film.id] = film;
    if (json['liked'] == true) _liked.add(film.id);
    if (json['saved'] == true) _saved.add(film.id);
    return film;
  }

  List<Film> _rememberAll(dynamic json) => [
    for (final f in (json as Map<String, dynamic>)['films'] as List)
      _remember(f as Map<String, dynamic>),
  ];

  @override
  Future<List<Film>> films([String query = '']) async {
    final core = await _allPages('/films', {if (query.isNotEmpty) 'q': query});
    // The catalog is an extra: it follows the app's own films and a failure
    // there never touches them.
    final extra = await _matchingCatalogFilms(query);
    return [...core, ...extra];
  }

  /// Reads every page of a film list (the server says whether another exists),
  /// so nothing past the first page is silently cut off.
  Future<List<Film>> _allPages(String path, Map<String, dynamic> query) async {
    final all = <Film>[];
    for (var page = 1; page <= _maxPages; page++) {
      final json =
          await _api.get(
                path,
                query: {...query, 'page': page, 'page_size': 100},
              )
              as Map<String, dynamic>;
      all.addAll(_rememberAll(json));
      if (json['has_more'] != true) break;
    }
    return all;
  }

  static const _maxPages = 20;

  Future<List<Film>> _matchingCatalogFilms(String query) async {
    await _catalogLoading;
    final text = query.toLowerCase();
    return [
      for (final film in _catalogFilms)
        if (text.isEmpty || film.title.toLowerCase().contains(text)) film,
    ];
  }

  @override
  Film? filmById(int id) => _films[id];

  @override
  Future<List<Episode>> episodes(int filmId) async {
    if (filmId >= catalogFilmIdBase) return _catalogEpisodes(filmId);
    final json = await _api.get('/films/$filmId') as Map<String, dynamic>;
    _remember(json['film'] as Map<String, dynamic>);
    final list = [
      for (final e in json['episodes'] as List)
        Episode.fromJson(e as Map<String, dynamic>),
    ];
    for (final e in list) {
      _episodeFilm[e.id] = e.filmId;
    }
    return list;
  }

  @override
  EpisodeAccess accessOf(int? userId, Episode episode) {
    if (episode.access != null) return episode.access!;
    // Catalog episodes carry no access: they are not sold here.
    return episode.priceCoins == 0 ? EpisodeAccess.free : EpisodeAccess.locked;
  }

  @override
  bool get playsVideo => true;

  @override
  Future<Playback> playback(int episodeId) async {
    final json = await _api.get('/episodes/$episodeId') as Map<String, dynamic>;
    final url = json['stream_url'] as String?;
    final episode = Episode.fromJson(json['episode'] as Map<String, dynamic>);
    _episodeFilm[episode.id] = episode.filmId;
    return Playback(
      episode: episode,
      streamUrl: url == null ? null : '$_origin$url',
    );
  }

  // ---- wallet and unlock ------------------------------------------------

  User _withBalance(int balance) {
    final user = _me!.copyWith(coinBalance: balance);
    _me = user;
    return user;
  }

  @override
  Future<User> refreshBalance(int userId) async {
    final json = await _api.get('/wallet') as Map<String, dynamic>;
    return _withBalance(json['coin_balance'] as int);
  }

  @override
  Future<User> unlock(int userId, int episodeId) async {
    final json =
        await _api.post('/episodes/$episodeId/unlock') as Map<String, dynamic>;
    final filmId = _episodeFilm[episodeId];
    if (filmId != null && (json['charged'] as int? ?? 0) > 0) {
      _unlockedFilmIds.add(filmId);
    }
    return _withBalance(json['balance'] as int);
  }

  @override
  Future<User> demoTopUp(int userId) async {
    final json =
        await _api.post('/wallet/topup', data: {'demo': true})
            as Map<String, dynamic>;
    return _withBalance(json['balance'] as int);
  }

  @override
  Future<User> topUpPack(int userId, CoinPack pack) async {
    final json =
        await _api.post('/wallet/topup', data: {'pack_id': pack.id})
            as Map<String, dynamic>;
    return _withBalance(json['balance'] as int);
  }

  @override
  Future<List<Transaction>> transactionsOf(int userId) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 0; page < _maxPages; page++) {
      final json =
          await _api.get(
                '/wallet/transactions',
                query: {'limit': 200, 'offset': rows.length},
              )
              as Map<String, dynamic>;
      rows.addAll((json['transactions'] as List).cast<Map<String, dynamic>>());
      if (json['has_more'] != true) break;
    }
    return [for (final row in rows) Transaction.fromJson(row)];
  }

  @override
  Future<List<CoinPack>> coinPacks() async {
    final json = await _api.get('/coin-packs') as Map<String, dynamic>;
    _demoCoins = json['demo_topup_coins'] as int;
    return [
      for (final p in json['coin_packs'] as List)
        CoinPack.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  int get episodePriceCoins => _typicalEpisodePrice;

  @override
  int get demoTopUpCoins => _demoCoins;

  // ---- admin ------------------------------------------------------------

  @override
  Future<List<Film>> reviewQueue() async =>
      _rememberAll(await _api.get('/admin/reviews'));

  @override
  Future<List<Film>> liveFilms() async => _rememberAll(
    await _api.get('/admin/films', query: {'status': 'approved'}),
  );

  @override
  Future<void> review(int filmId, String status, {String? note}) async {
    await _api.post(
      '/admin/films/$filmId/review',
      data: {'status': status, 'note': ?note},
    );
  }

  @override
  Future<AdminSales> adminSales() async {
    final json = await _api.get('/admin/sales') as Map<String, dynamic>;
    final coins = json['coins'] as Map<String, dynamic>;
    final usd = json['simulated_payments'] as Map<String, dynamic>;
    double dollars(String key) =>
        ((usd[key] as Map<String, dynamic>)['simulated_usd'] as num).toDouble();
    return AdminSales(
      // Simulated dollars only; coins stay in their own fields.
      totalUsd: dollars('coin_topups'),
      coinsSpent: coins['coins_spent'] as int,
      unlockCount: coins['unlock_count'] as int,
    );
  }

  // ---- like, save, comments ---------------------------------------------

  bool _isCatalog(int filmId) => filmId >= catalogFilmIdBase;

  @override
  bool isLiked(int userId, int filmId) => _liked.contains(filmId);

  @override
  bool isSaved(int userId, int filmId) => _saved.contains(filmId);

  @override
  Future<void> toggleLike(int userId, int filmId) async {
    if (_isCatalog(filmId)) {
      _liked.contains(filmId) ? _liked.remove(filmId) : _liked.add(filmId);
      return;
    }
    final on = !_liked.contains(filmId);
    final json = on
        ? await _api.post('/films/$filmId/like')
        : await _api.delete('/films/$filmId/like');
    on ? _liked.add(filmId) : _liked.remove(filmId);
    final film = _films[filmId];
    if (film != null) {
      _films[filmId] = film.copyWith(
        likeCount: (json as Map<String, dynamic>)['like_count'] as int,
      );
    }
  }

  @override
  Future<void> toggleSave(int userId, int filmId) async {
    if (_isCatalog(filmId)) {
      _saved.contains(filmId) ? _saved.remove(filmId) : _saved.add(filmId);
      return;
    }
    final on = !_saved.contains(filmId);
    on
        ? await _api.post('/films/$filmId/watchlist')
        : await _api.delete('/films/$filmId/watchlist');
    on ? _saved.add(filmId) : _saved.remove(filmId);
    // The saved list on Profile reads this, so it must follow the heart.
    _watchlistIds = on
        ? [filmId, ..._watchlistIds.where((id) => id != filmId)]
        : [..._watchlistIds.where((id) => id != filmId)];
  }

  @override
  List<FilmComment> commentsOf(int filmId) => _comments[filmId] ?? const [];

  @override
  Future<void> loadComments(int filmId) async {
    if (_isCatalog(filmId)) return;
    final json =
        await _api.get('/films/$filmId/comments') as Map<String, dynamic>;
    _comments[filmId] = [
      for (final c in json['comments'] as List)
        FilmComment(
          id: (c as Map<String, dynamic>)['id'] as int,
          userId: c['user_id'] as int,
          username: c['username'] as String,
          body: c['body'] as String,
        ),
    ];
  }

  @override
  Future<void> addComment(int userId, int filmId, String body) async {
    if (_isCatalog(filmId)) {
      throw const ApiException(
        code: 'NOT_SUPPORTED',
        message: 'Comments are not available for catalog series.',
      );
    }
    await _api.post('/films/$filmId/comments', data: {'body': body});
    await loadComments(filmId);
    final film = _films[filmId];
    if (film != null) {
      _films[filmId] = film.copyWith(commentCount: film.commentCount + 1);
    }
  }

  @override
  Future<void> removeComment(int commentId) async {
    await _api.delete('/comments/$commentId');
    for (final entry in _comments.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((c) => c.id == commentId);
      if (entry.value.length != before) {
        final film = _films[entry.key];
        if (film != null) {
          _films[entry.key] = film.copyWith(
            commentCount: film.commentCount - 1,
          );
        }
      }
    }
  }

  // ---- library lists ----------------------------------------------------

  @override
  Future<void> refreshLibrary(int userId) async {
    final json = await _api.get('/watchlist') as Map<String, dynamic>;
    _watchlistIds = [for (final id in json['film_ids'] as List) id as int];
    _saved
      ..removeWhere((id) => !_isCatalog(id))
      ..addAll(_watchlistIds);
    // Purchases are read from the unlock rows, never guessed from the ledger.
    final unlocked = await _api.get('/wallet/unlocked') as Map<String, dynamic>;
    _unlockedFilmIds
      ..clear()
      ..addAll([
        for (final row in unlocked['unlocked'] as List)
          (row as Map<String, dynamic>)['film_id'] as int,
      ]);
    for (final id in {..._watchlistIds, ..._unlockedFilmIds}) {
      if (_films.containsKey(id)) continue;
      try {
        await episodes(id);
      } on ApiException {
        // A film that is gone is simply left out of the list.
      }
    }
  }

  @override
  List<Film> watchlistOf(int userId) => [
    for (final id in _watchlistIds) ?_films[id],
  ];

  @override
  List<Film> unlockedFilmsOf(int userId) => [
    for (final id in _unlockedFilmIds) ?_films[id],
  ];

  // ---- optional Series Jeen catalog -------------------------------------

  static const _catalogPlatforms = 3;
  static const _catalogPerPlatform = 12;

  /// Loads a few catalog series for the feed after the app's own films. If the
  /// catalog is off, has no key or is down, nothing here changes.
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
      final withPoster = page.items.where((d) => d.posterUrl != null);
      lists.add(withPoster.take(_catalogPerPlatform).toList());
    }
    _catalogFilms = [
      for (var i = 0; i < _catalogPerPlatform; i++)
        for (final list in lists)
          if (i < list.length) catalogFilm(list[i]),
    ];
  }

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
      status: 'approved',
      genreName: drama.genres.isEmpty ? '' : drama.genres.first,
      genreTags: drama.genres,
      episodeCount: drama.episodeCount,
      catalogDramaId: drama.id,
    );
  }

  List<Episode> _catalogEpisodes(int filmId) {
    final film = _films[filmId];
    return [
      for (var n = 1; n <= (film?.episodeCount ?? 0); n++)
        Episode(
          id: filmId * 1000 + n,
          filmId: filmId,
          episodeNo: n,
          title: 'Episode $n',
          durationSec: 0,
          isFree: true,
          priceCoins: 0,
        ),
    ];
  }
}
