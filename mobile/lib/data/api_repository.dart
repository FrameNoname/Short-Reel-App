import 'package:dio/dio.dart';

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
import 'film_filter.dart';

/// The real thing: every core call goes to the REST API and MySQL behind it.
///
/// Small caches (films, channels, like/save/follow flags) let the screens read
/// synchronously what the last request returned. Not wired to the backend yet,
/// and kept only on the device for the session: comment likes.
class ApiRepository implements AppRepository {
  ApiRepository({
    required ApiClient client,
    required this._tokens,
    String? origin,
  }) : _api = client,
       _origin = origin ?? apiOrigin;

  /// Catalog series get ids from here up, so they never collide with real ids.
  static const catalogFilmIdBase = 100000000;

  /// The channel external catalog series are shown under. It is not a real
  /// account, is not verified and is never labelled as AI.
  static const catalogChannelId = -1;

  static const _typicalEpisodePrice = 20;

  final ApiClient _api;
  final TokenStore _tokens;
  final String _origin;

  User? _me;
  int _demoCoins = 100;

  final Map<int, Film> _films = {};
  final Map<int, User> _users = {};
  final Map<int, int> _followers = {};
  final Set<int> _liked = {};
  final Set<int> _saved = {};
  final Set<int> _following = {};
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
    _users[user.id] = user;
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
  Future<User> register(String username, String password, UserRole role) async {
    final json =
        await _api.post(
              '/auth/register',
              data: {
                'username': username,
                'password': password,
                'role': role == UserRole.creator ? 'creator' : 'viewer',
              },
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
    _following.clear();
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

  // ---- films and channels -----------------------------------------------

  Film _remember(Map<String, dynamic> json) {
    final film = Film.fromJson(json);
    _films[film.id] = film;
    final creator = json['creator'] as Map<String, dynamic>?;
    if (creator != null && !_users.containsKey(film.creatorId)) {
      _users[film.creatorId] = User(
        id: film.creatorId,
        username: creator['username'] as String,
        displayName: creator['name'] as String?,
        role: UserRole.values.byName(creator['role'] as String),
        coinBalance: 0,
      );
    }
    if (creator?['follower_count'] is int) {
      _followers[film.creatorId] = creator!['follower_count'] as int;
    }
    if (json['liked'] == true) _liked.add(film.id);
    if (json['saved'] == true) _saved.add(film.id);
    if (json['following_creator'] == true) _following.add(film.creatorId);
    return film;
  }

  List<Film> _rememberAll(dynamic json) => [
    for (final f in (json as Map<String, dynamic>)['films'] as List)
      _remember(f as Map<String, dynamic>),
  ];

  static const _lengthParam = {
    LengthFilter.under5: 'under5',
    LengthFilter.from5to15: '5to15',
    LengthFilter.from15to30: '15to30',
  };

  @override
  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]) async {
    final core = await _allPages('/films', {
      if (filter.query.isNotEmpty) 'q': filter.query,
      if (filter.genres.isNotEmpty) 'genre': filter.genres.join(','),
      if (filter.aiTools.isNotEmpty) 'ai_tool': filter.aiTools.join(','),
      if (_lengthParam[filter.length] != null)
        'length': _lengthParam[filter.length],
    });
    // The catalog is an extra: it follows the app's own films and a failure
    // there never touches them.
    final extra = await _matchingCatalogFilms(filter);
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

  Future<List<Film>> _matchingCatalogFilms(FilmFilter filter) async {
    // The catalog has no AI tool or running time, so those filters hide it.
    if (filter.aiTools.isNotEmpty || filter.length != LengthFilter.any) {
      return const [];
    }
    await _catalogLoading;
    final query = filter.query.toLowerCase();
    return [
      for (final film in _catalogFilms)
        if ((query.isEmpty || film.title.toLowerCase().contains(query)) &&
            (filter.genres.isEmpty ||
                film.genreTags.any(filter.genres.contains)))
          film,
    ];
  }

  @override
  Future<List<Film>> followingFilms(int userId) async {
    final all = await films();
    return all.where((f) => _following.contains(f.creatorId)).toList();
  }

  @override
  Film? filmById(int id) => _films[id];

  @override
  User? userById(int id) => _users[id];

  @override
  List<User> searchCreators(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return const [];
    return [
      for (final user in _users.values)
        if (user.role != UserRole.viewer &&
            ((user.displayName ?? '').toLowerCase().contains(text) ||
                user.username.toLowerCase().contains(text)))
          user,
    ];
  }

  @override
  Future<List<Film>> filmsOf(int creatorId) async {
    final isOwn = creatorId == _me?.id;
    if (!isOwn) return _allPages('/films', {'creator_id': creatorId});
    return _rememberAll(await _api.get('/creator/films'));
  }

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

  // ---- creator: upload, edit, delete, earnings --------------------------

  @override
  Future<Film> upload({
    required int creatorId,
    required String title,
    required String genre,
    required String aiTool,
    required String promptCredit,
    required List<EpisodeDraft> episodes,
  }) async {
    final created =
        await _api.post(
              '/films',
              data: {
                'title': title,
                'genre': genre,
                'ai_tool': aiTool,
                'prompt_credit': promptCredit,
                'is_ai_generated': true,
              },
            )
            as Map<String, dynamic>;
    final film = _remember(created['film'] as Map<String, dynamic>);
    try {
      for (var i = 0; i < episodes.length; i++) {
        final draft = episodes[i];
        await _api.post(
          '/films/${film.id}/episodes',
          data: FormData.fromMap({
            'episode_no': i + 1,
            'title': 'Episode ${i + 1}',
            'price_coins': draft.priceCoins,
            'video': MultipartFile.fromBytes(
              draft.bytes!,
              filename: draft.fileName,
              contentType: DioMediaType('video', 'mp4'),
            ),
          }),
        );
      }
    } on Object {
      // Do not leave a half-uploaded film waiting for review.
      await _api.delete('/films/${film.id}').catchError((Object _) => null);
      _films.remove(film.id);
      rethrow;
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
    Map<int, int> episodePrices = const {},
  }) async {
    await _api.put(
      '/films/$filmId',
      data: {
        'title': title,
        'genre': genre,
        'ai_tool': aiTool,
        'prompt_credit': promptCredit,
        if (episodePrices.isNotEmpty)
          'episode_prices': [
            for (final e in episodePrices.entries)
              {'id': e.key, 'price_coins': e.value},
          ],
        // Kept as it was, because an update replaces every field.
        if (_films[filmId]?.synopsis != null)
          'synopsis': _films[filmId]!.synopsis,
      },
    );
  }

  @override
  Future<void> deleteFilm(int filmId) async {
    await _api.delete('/films/$filmId');
    _films.remove(filmId);
  }

  @override
  Future<void> setEpisodePrices(Map<int, int> pricesByEpisodeId) async {
    for (final entry in pricesByEpisodeId.entries) {
      await _api.put(
        '/episodes/${entry.key}',
        data: {'price_coins': entry.value},
      );
    }
  }

  @override
  Future<EpisodePricing> pricingOf(int filmId) async {
    final list = await episodes(filmId);
    final paid = list.where((e) => !e.isFree).toList();
    final prices = paid.map((e) => e.priceCoins);
    return EpisodePricing(
      freeCount: list.length - paid.length,
      paidCount: paid.length,
      priceCoins: paid.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b),
      maxPriceCoins: paid.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  Future<Earnings> earningsOf(int creatorId) async {
    final json = await _api.get('/creator/earnings') as Map<String, dynamic>;
    final own = await filmsOf(creatorId);
    return Earnings(
      coins: json['coins_earned'] as int,
      unlocks: json['unlock_count'] as int,
      likes: own.fold(0, (sum, f) => sum + f.likeCount),
      adminSharePercent: json['admin_share_percent'] as int?,
      coinsByFilm: {
        for (final f in json['films'] as List)
          (f as Map<String, dynamic>)['film_id'] as int:
              f['coins_earned'] as int,
      },
    );
  }

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
      adminCoins: coins['admin_share'] as int,
      coinsSpent: coins['coins_spent'] as int,
      creatorCoins: coins['creator_share'] as int,
      unlockCount: coins['unlock_count'] as int,
    );
  }

  @override
  Future<int> adminSharePercent() async {
    final json =
        await _api.get('/admin/settings/revenue-share') as Map<String, dynamic>;
    return json['admin_share_percent'] as int;
  }

  @override
  Future<void> setAdminSharePercent(int percent) async {
    await _api.put(
      '/admin/settings/revenue-share',
      data: {'admin_share_percent': percent},
    );
  }

  // ---- like, save, follow, comments -----------------------------------

  bool _isCatalog(int filmId) => filmId >= catalogFilmIdBase;

  @override
  bool isLiked(int userId, int filmId) => _liked.contains(filmId);

  @override
  bool isSaved(int userId, int filmId) => _saved.contains(filmId);

  @override
  bool isFollowing(int userId, int creatorId) => _following.contains(creatorId);

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
  Future<void> toggleFollow(int userId, int creatorId) async {
    if (creatorId == catalogChannelId) return;
    final on = !_following.contains(creatorId);
    on
        ? await _api.post('/creators/$creatorId/follow')
        : await _api.delete('/creators/$creatorId/follow');
    if (on) {
      _following.add(creatorId);
    } else {
      _following.remove(creatorId);
    }
    _followers[creatorId] = (_followers[creatorId] ?? 0) + (on ? 1 : -1);
  }

  @override
  int followerCount(int userId) => _followers[userId] ?? 0;

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

  // Local to the session; the backend has no comment likes.
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

  @override
  List<User> followingOf(int userId) => userId == _me?.id
      // Only the signed-in person's follows are known. Another person's list
      // is not available from the API, so none is shown rather than these.
      ? [for (final id in _following) ?_users[id]]
      : const [];

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
      creatorId: catalogChannelId,
      title: drama.title,
      synopsis: drama.description,
      posterUrl: drama.posterUrl,
      genreId: 0,
      aiToolId: 0,
      promptCredit: null,
      // Nothing confirms how these were made, so they carry no AI label.
      isAiGenerated: false,
      status: 'approved',
      creatorName: 'Series Jeen',
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

  @override
  List<String> catalogGenres() {
    final counts = <String, int>{};
    for (final film in _catalogFilms) {
      for (final tag in film.genreTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names.take(12).toList();
  }
}
