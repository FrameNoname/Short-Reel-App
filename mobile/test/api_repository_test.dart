import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/api_repository.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/data/film_filter.dart';
import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/token_store.dart';

/// Answers requests from a table instead of the network.
class _FakeServer implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};
  final List<RequestOptions> seen = [];

  void json(String route, Object body, {int status = 200}) {
    routes[route] = (_) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'no route'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokens implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const _user = {
  'id': 6,
  'username': 'viewer01',
  'display_name': 'Demo Viewer',
  'role': 'viewer',
  'coin_balance': 80,
  'bio': null,
};

const _film = {
  'id': 1,
  'creator_id': 2,
  'creator': {
    'id': 2,
    'username': 'kestrel_studio',
    'name': 'Kestrel Studio',
    'role': 'creator',
    'follower_count': 4,
  },
  'title': 'Salt & Signal',
  'synopsis': 'A lighthouse keeper.',
  'poster_url': null,
  'genre_id': 6,
  'genre': 'Mystery',
  'ai_tool_id': 1,
  'ai_tool': 'Text-to-video',
  'prompt_credit': 'Prompt',
  'is_ai_generated': true,
  'status': 'approved',
  'episode_count': 8,
  'like_count': 3,
  'comment_count': 1,
  'liked': true,
};

({ApiRepository repo, _FakeServer server, _MemoryTokens tokens, ApiClient api})
_setUp() {
  final server = _FakeServer();
  final tokens = _MemoryTokens();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
    ..httpClientAdapter = server;
  final api = ApiClient(tokens: tokens, dio: dio);
  final repo = ApiRepository(
    client: api,
    tokens: tokens,
    origin: 'http://api.test',
  );
  return (repo: repo, server: server, tokens: tokens, api: api);
}

void main() {
  test('login keeps the token and sends it with later requests', () async {
    final s = _setUp();
    s.server.json('POST /auth/login', {'token': 'abc', 'user': _user});
    s.server.json('GET /wallet/transactions', {'transactions': []});

    final user = await s.repo.login('viewer01', '6666');
    expect(user.username, 'viewer01');
    expect(user.role, UserRole.viewer);
    expect(s.tokens.token, 'abc');

    await s.repo.transactionsOf(6);
    expect(s.server.seen.last.headers['Authorization'], 'Bearer abc');
  });

  test('logout clears the token even when the server is down', () async {
    final s = _setUp();
    s.server.json('POST /auth/login', {'token': 'abc', 'user': _user});
    await s.repo.login('viewer01', '6666');
    // No route for /auth/logout: the fake answers 404.
    await s.repo.logout();
    expect(s.tokens.token, isNull);
    expect(await s.repo.restoreSession(), isNull);
  });

  test('a stored token restores the session through /auth/me', () async {
    final s = _setUp();
    s.tokens.token = 'saved';
    s.server.json('GET /auth/me', {'user': _user});
    final user = await s.repo.restoreSession();
    expect(user?.id, 6);
  });

  test('a rejected stored token is thrown away', () async {
    final s = _setUp();
    s.tokens.token = 'old';
    s.server.json('GET /auth/me', {
      'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
    }, status: 401);
    expect(await s.repo.restoreSession(), isNull);
    expect(s.tokens.token, isNull);
  });

  test('a 401 on a request that sent a token calls onUnauthorized', () async {
    final s = _setUp();
    var called = 0;
    s.api.onUnauthorized = () => called++;
    s.tokens.token = 'old';
    s.server.json('GET /wallet/transactions', {
      'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
    }, status: 401);
    await expectLater(s.repo.transactionsOf(6), throwsA(isA<ApiException>()));
    expect(called, 1);
  });

  test('after a 401 the refused token is not sent again', () async {
    final s = _setUp();
    s.tokens.token = 'old';
    s.server.json('GET /wallet/transactions', {
      'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
    }, status: 401);
    s.server.json('GET /films', {'films': []});
    await expectLater(s.repo.transactionsOf(6), throwsA(isA<ApiException>()));

    expect(s.tokens.token, isNull);
    await s.repo.films();
    expect(s.server.seen.last.path, '/films');
    expect(s.server.seen.last.headers.containsKey('Authorization'), isFalse);
  });

  test('a wrong password does not count as an expired session', () async {
    final s = _setUp();
    var called = 0;
    s.api.onUnauthorized = () => called++;
    s.tokens.token = 'old';
    s.server.json('POST /auth/login', {
      'error': {'code': 'UNAUTHENTICATED', 'message': 'wrong'},
    }, status: 401);
    await expectLater(s.repo.login('a', 'b'), throwsA(isA<ApiException>()));
    expect(called, 0);
  });

  test('films come from the API with the AI label and counts', () async {
    final s = _setUp();
    s.server.json('GET /films', {
      'films': [_film],
    });
    final films = await s.repo.films();
    expect(films.single.title, 'Salt & Signal');
    expect(films.single.isAiGenerated, isTrue);
    expect(films.single.genreName, 'Mystery');
    expect(films.single.likeCount, 3);
    expect(s.repo.isLiked(6, 1), isTrue);
    expect(s.repo.userById(2)?.username, 'kestrel_studio');
    expect(s.repo.followerCount(2), 4);
  });

  test('search sends the filters to the backend', () async {
    final s = _setUp();
    s.server.json('GET /films', {'films': []});
    await s.repo.films(
      const FilmFilter(
        query: 'moon',
        genres: {'Sci-Fi', 'Drama'},
        aiTools: {'Mixed'},
        length: LengthFilter.from5to15,
      ),
    );
    final query = s.server.seen.last.queryParameters;
    expect(query['q'], 'moon');
    expect(query['genre'], 'Sci-Fi,Drama');
    expect(query['ai_tool'], 'Mixed');
    expect(query['length'], '5to15');
  });

  test('a locked episode comes back without a playback link', () async {
    final s = _setUp();
    s.server.json('GET /episodes/3', {
      'episode': {
        'id': 3,
        'film_id': 1,
        'episode_no': 3,
        'title': 'Episode 3',
        'duration_sec': 105,
        'is_free': false,
        'price_coins': 20,
        'access': 'login_required',
      },
      'film': {'id': 1, 'title': 'Salt & Signal'},
      'stream_url': null,
    });
    final playback = await s.repo.playback(3);
    expect(playback.streamUrl, isNull);
    expect(s.repo.accessOf(null, playback.episode), EpisodeAccess.locked);
  });

  test('a playable episode gets an absolute link', () async {
    final s = _setUp();
    s.server.json('GET /episodes/1', {
      'episode': {
        'id': 1,
        'film_id': 1,
        'episode_no': 1,
        'title': 'Episode 1',
        'duration_sec': 75,
        'is_free': true,
        'price_coins': 0,
        'access': 'free',
      },
      'film': {'id': 1, 'title': 'Salt & Signal'},
      'stream_url': '/api/episodes/1/stream?t=xyz',
    });
    final playback = await s.repo.playback(1);
    expect(playback.streamUrl, 'http://api.test/api/episodes/1/stream?t=xyz');
    expect(s.repo.accessOf(null, playback.episode), EpisodeAccess.free);
  });

  test('the server alone decides the price of a top-up', () async {
    final s = _setUp();
    s.server.json('POST /auth/login', {'token': 'abc', 'user': _user});
    await s.repo.login('viewer01', '6666');
    s.server.json('POST /wallet/topup', {'balance': 180}, status: 201);
    final user = await s.repo.demoTopUp(6);
    expect(user.coinBalance, 180);
    expect(s.server.seen.last.data, {'demo': true});
  });

  test('unlock returns the new balance from the server', () async {
    final s = _setUp();
    s.server.json('POST /auth/login', {'token': 'abc', 'user': _user});
    await s.repo.login('viewer01', '6666');
    s.server.json('POST /episodes/5/unlock', {
      'access': 'unlocked',
      'charged': 20,
      'balance': 60,
    });
    expect((await s.repo.unlock(6, 5)).coinBalance, 60);
  });

  test('insufficient coins surface as an API error', () async {
    final s = _setUp();
    s.server.json('POST /episodes/5/unlock', {
      'error': {'code': 'INSUFFICIENT_COINS', 'message': 'Not enough coins'},
    }, status: 402);
    await expectLater(
      s.repo.unlock(6, 5),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INSUFFICIENT_COINS'),
      ),
    );
  });

  test('admin sales keep coins and simulated dollars apart', () async {
    final s = _setUp();
    s.server.json('GET /admin/sales', {
      'coins': {
        'coins_spent': 100,
        'creator_share': 70,
        'admin_share': 30,
        'unlock_count': 5,
      },
      'simulated_payments': {
        'coin_topups': {'simulated_usd': 4.5},
        'subscriptions': {'simulated_usd': 6.99},
      },
    });
    final sales = await s.repo.adminSales();
    expect(sales.adminCoins, 30);
    expect(sales.creatorCoins, 70);
    expect(sales.coinsSpent, 100);
    expect(sales.totalUsd, closeTo(11.49, 0.001));
  });

  test('an upload is not reported as done when a file is refused', () async {
    final s = _setUp();
    s.server.json('POST /films', {
      'film': {..._film, 'id': 9, 'status': 'pending'},
    }, status: 201);
    s.server.json('POST /films/9/episodes', {
      'error': {'code': 'VALIDATION_ERROR', 'message': 'Not a valid MP4'},
    }, status: 400);
    s.server.json('DELETE /films/9', {});

    await expectLater(
      s.repo.upload(
        creatorId: 2,
        title: 'T',
        genre: 'Drama',
        aiTool: 'Mixed',
        promptCredit: 'p',
        episodes: [
          EpisodeDraft(
            fileName: 'a.mp4',
            priceCoins: 0,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      ),
      throwsA(isA<ApiException>()),
    );
    // The half-made film is removed again.
    expect(s.server.seen.last.method, 'DELETE');
    expect(s.server.seen.last.path, '/films/9');
  });

  test('an upload sends the video as multipart with its price', () async {
    final s = _setUp();
    s.server.json('POST /films', {
      'film': {..._film, 'id': 9, 'status': 'pending'},
    }, status: 201);
    s.server.json('POST /films/9/episodes', {'episode': {}}, status: 201);
    final film = await s.repo.upload(
      creatorId: 2,
      title: 'T',
      genre: 'Drama',
      aiTool: 'Mixed',
      promptCredit: 'p',
      episodes: [
        EpisodeDraft(
          fileName: 'a.mp4',
          priceCoins: 25,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    expect(film.id, 9);
    final create = s.server.seen[0].data as Map;
    expect(create['is_ai_generated'], true);
    final form = s.server.seen[1].data as FormData;
    expect(form.files.single.key, 'video');
    expect(form.fields.firstWhere((f) => f.key == 'price_coins').value, '25');
  });

  test('catalog series are never labelled AI and stay out of real ids', () {
    final s = _setUp();
    final film = s.repo.catalogFilm(
      const CatalogDrama(
        id: 7,
        title: 'Series Seven',
        description: null,
        episodeCount: 3,
        genres: ['Drama'],
        posterUrl: null,
        thaiDub: false,
        thaiSub: false,
      ),
    );
    expect(film.isAiGenerated, isFalse);
    expect(film.id, greaterThanOrEqualTo(ApiRepository.catalogFilmIdBase));
    expect(film.creatorId, ApiRepository.catalogChannelId);
    expect(s.repo.userById(film.creatorId)?.isVerified ?? false, isFalse);
  });

  test('the app still lists its own films when the catalog is down', () async {
    final s = _setUp();
    s.server.json('GET /films', {
      'films': [_film],
    });
    final films = await s.repo.films();
    expect(films, hasLength(1));
    expect(films.single.catalogDramaId, isNull);
  });
}
