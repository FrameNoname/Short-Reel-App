import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/wallet_controller.dart';
import 'package:shortreel/data/api_repository.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/token_store.dart';

/// A fake server whose answers can be held back and released in any order.
class _GatedServer implements HttpClientAdapter {
  final Map<String, Object Function(RequestOptions)> routes = {};
  final Map<String, Completer<void>> gates = {};
  final Map<String, Completer<void>> taken = {};
  final List<RequestOptions> seen = [];

  void route(
    String key,
    Object Function(RequestOptions) body, {
    int status = 200,
  }) {
    routes[key] = (o) => (status, body(o));
  }

  /// Holds the next answer for [key] until [release] is called.
  void hold(String key) => gates[key] = Completer<void>();

  void release(String key) => taken[key]!.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final key = '${options.method} ${options.path}';
    final gate = gates.remove(key);
    if (gate != null) taken[key] = gate;
    // The answer is decided when the request arrives, like a real server.
    final (status, body) =
        (routes[key] ??
                (_) => (
                  404,
                  {
                    'error': {'code': 'NOT_FOUND', 'message': 'no route'},
                  },
                ))(options)
            as (int, Object);
    if (gate != null) await gate.future;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
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

Map<String, Object?> _userJson(int id, String name, int coins) => {
  'id': id,
  'username': name,
  'display_name': name,
  'role': 'viewer',
  'coin_balance': coins,
  'bio': null,
};

({
  _GatedServer server,
  _MemoryTokens tokens,
  ApiClient api,
  ApiRepository repo,
  AuthController auth,
  int unauthorizedCalls,
})
_world() {
  final server = _GatedServer();
  final tokens = _MemoryTokens();
  final api = ApiClient(
    tokens: tokens,
    dio: Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..httpClientAdapter = server,
  );
  final repo = ApiRepository(
    client: api,
    tokens: tokens,
    origin: 'http://api.test',
  );
  final auth = AuthController(repo);
  server
    ..route('POST /auth/login', (o) {
      final name = (o.data as Map)['username'] as String;
      return {
        'token': 'token-$name',
        'user': name == 'alice'
            ? _userJson(1, 'alice', 10)
            : _userJson(2, 'bob', 10),
      };
    })
    ..route('POST /auth/logout', (_) => {'status': 'ok'});
  return (
    server: server,
    tokens: tokens,
    api: api,
    repo: repo,
    auth: auth,
    unauthorizedCalls: 0,
  );
}

void main() {
  test(
    "a slow top-up of the previous person never changes the next person's balance",
    () async {
      final w = _world();
      w.server
        ..route(
          'POST /wallet/topup',
          (_) => {'balance': 180, 'coins_added': 100},
        )
        ..route('GET /wallet', (_) => {'coin_balance': 10})
        ..route(
          'GET /wallet/transactions',
          (_) => {'transactions': [], 'has_more': false},
        )
        ..route(
          'GET /coin-packs',
          (_) => {
            'coin_packs': [],
            'demo_topup_coins': 100,
            'subscription_price_usd': 6.99,
          },
        )
        ..route(
          'GET /subscription',
          (_) => {'active': false, 'subscription': null, 'price_usd': 6.99},
        );
      await w.auth.login('alice', 'x');
      final wallet = WalletController(w.repo, w.auth);

      w.server.hold('POST /wallet/topup');
      final topUp = wallet
          .demoTopUp(); // alice's request, answer still on its way
      await Future<void>.delayed(Duration.zero);

      await w.auth.logout();
      await w.auth.login('bob', 'x');
      expect(w.auth.user!.id, 2);
      expect(w.auth.user!.coinBalance, 10);

      w.server.release('POST /wallet/topup');
      await topUp; // dropped silently
      expect(w.auth.user!.id, 2);
      expect(
        w.auth.user!.coinBalance,
        10,
        reason: "alice's answer must not touch bob",
      );
      expect(w.tokens.token, 'token-bob');
    },
  );

  test(
    'a profile answer that arrives after logout does not bring the person back',
    () async {
      final w = _world();
      w.server.route(
        'PUT /auth/me',
        (_) => {'user': _userJson(1, 'alice', 10)},
      );
      await w.auth.login('alice', 'x');

      w.server.hold('PUT /auth/me');
      final saving = w.auth.updateProfile(displayName: 'New', bio: '');
      await Future<void>.delayed(Duration.zero);
      await w.auth.logout();
      w.server.release('PUT /auth/me');
      await saving.catchError((Object _) {});

      expect(w.auth.user, isNull);
      expect(w.auth.isLoggedIn, isFalse);
      expect(w.tokens.token, isNull);
    },
  );

  test(
    "a restore that finishes after someone else logged in does not overwrite them",
    () async {
      final w = _world();
      w.tokens.token = 'token-old';
      w.server.route(
        'GET /auth/me',
        (_) => {'user': _userJson(1, 'alice', 10)},
      );
      w.server.hold('GET /auth/me');
      final restoring = w.auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      await w.auth.login('bob', 'x');
      w.server.release('GET /auth/me');
      await restoring;
      expect(w.auth.user!.id, 2);
      expect(w.auth.isRestoring, isFalse);
    },
  );

  test(
    "an old 401 does not clear the new person's token or log them out",
    () async {
      final w = _world();
      var loggedOut = 0;
      w.api.onUnauthorized = () => loggedOut++;
      w.server.route(
        'GET /wallet',
        (_) => {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
        },
        status: 401,
      );
      await w.auth.login('alice', 'x');

      w.server.hold('GET /wallet');
      final late = w.api
          .get('/wallet')
          .then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(Duration.zero);
      await w.auth.logout();
      await w.auth.login('bob', 'x');
      w.server.release('GET /wallet');

      expect(isStaleSession(await late as Object), isTrue);
      expect(w.tokens.token, 'token-bob');
      expect(loggedOut, 0);
    },
  );

  test('a 401 for the current token still clears it and logs out', () async {
    final w = _world();
    var loggedOut = 0;
    w.api.onUnauthorized = () => loggedOut++;
    w.server.route(
      'GET /wallet',
      (_) => {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
      },
      status: 401,
    );
    await w.auth.login('alice', 'x');
    await expectLater(w.api.get('/wallet'), throwsA(isA<ApiException>()));
    expect(w.tokens.token, isNull);
    expect(loggedOut, 1);
  });

  test(
    'loading the wallet reads the current balance from the server',
    () async {
      final w = _world();
      w.server
        ..route('GET /wallet', (_) => {'coin_balance': 55})
        ..route(
          'GET /wallet/transactions',
          (_) => {'transactions': [], 'has_more': false},
        )
        ..route(
          'GET /coin-packs',
          (_) => {
            'coin_packs': [],
            'demo_topup_coins': 100,
            'subscription_price_usd': 6.99,
          },
        )
        ..route(
          'GET /subscription',
          (_) => {'active': false, 'subscription': null, 'price_usd': 6.99},
        );
      await w.auth.login('alice', 'x');
      expect(w.auth.user!.coinBalance, 10);
      final wallet = WalletController(w.repo, w.auth);
      await wallet.load();
      expect(wallet.balance, 55, reason: 'changed on another device');
      expect(wallet.error, isNull);
    },
  );

  test(
    'an older wallet load that finishes last cannot overwrite a newer one',
    () async {
      final w = _world();
      var balance = 10;
      w.server
        ..route('GET /wallet', (_) => {'coin_balance': balance})
        ..route(
          'GET /wallet/transactions',
          (_) => {'transactions': [], 'has_more': false},
        )
        ..route(
          'GET /coin-packs',
          (_) => {
            'coin_packs': [],
            'demo_topup_coins': 100,
            'subscription_price_usd': 6.99,
          },
        )
        ..route(
          'GET /subscription',
          (_) => {'active': false, 'subscription': null, 'price_usd': 6.99},
        );
      await w.auth.login('alice', 'x');
      final wallet = WalletController(w.repo, w.auth);

      w.server.hold('GET /wallet');
      final first = wallet.load(); // answers 10, held back
      await Future<void>.delayed(Duration.zero);
      balance = 99;
      await wallet.load(); // answers 99, finishes first
      w.server.release('GET /wallet');
      await first;
      expect(wallet.balance, 99);
    },
  );

  test(
    'purchases are read from the unlock rows, not the first ledger page',
    () async {
      final w = _world();
      w.server
        ..route('GET /watchlist', (_) => {'film_ids': []})
        ..route(
          'GET /wallet/unlocked',
          (_) => {
            'unlocked': [
              {'episode_id': 9, 'film_id': 3, 'film_title': 'Old buy'},
            ],
          },
        )
        ..route(
          'GET /films/3',
          (_) => {
            'film': {
              'id': 3,
              'creator_id': 2,
              'title': 'Old buy',
              'genre_id': 1,
              'genre': 'Drama',
              'ai_tool_id': 1,
              'ai_tool': 'Mixed',
              'is_ai_generated': true,
              'status': 'approved',
              'episode_count': 8,
              'like_count': 0,
              'comment_count': 0,
            },
            'episodes': [],
          },
        );
      await w.auth.login('alice', 'x');
      await w.repo.refreshLibrary(1);
      expect(w.repo.unlockedFilmsOf(1).map((f) => f.id), [3]);
    },
  );

  test(
    'film lists follow has_more instead of stopping at the first page',
    () async {
      final w = _world();
      Map<String, Object?> film(int id) => {
        'id': id,
        'creator_id': 2,
        'title': 'Film $id',
        'genre_id': 1,
        'genre': 'Drama',
        'ai_tool_id': 1,
        'ai_tool': 'Mixed',
        'is_ai_generated': true,
        'status': 'approved',
        'episode_count': 1,
        'like_count': 0,
        'comment_count': 0,
      };
      w.server.route('GET /films', (o) {
        final page = o.queryParameters['page'] as int;
        return {
          'films': [film(page * 10), film(page * 10 + 1)],
          'page': page,
          'has_more': page < 3,
        };
      });
      final films = await w.repo.films();
      expect(films.map((f) => f.id), [10, 11, 20, 21, 30, 31]);
    },
  );

  test('User role stays viewer in the fixture', () {
    expect(UserRole.values, contains(UserRole.viewer));
  });
}
