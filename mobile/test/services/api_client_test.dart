// Person 3: how every request is sent, and what happens to the login token.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/errors.dart';

import '../support/fake_dio.dart';

void main() {
  late List<RequestOptions> sent;
  late MemoryTokens tokens;

  ApiClient client(FakeAnswer answer, {void Function()? onUnauthorized}) =>
      ApiClient(
        tokens: tokens,
        dio: fakeDio(sent, answer),
        onUnauthorized: onUnauthorized,
      );

  setUp(() {
    sent = [];
    tokens = MemoryTokens();
  });

  test('the base URL is the override, else the web or emulator host', () {
    expect(resolveApiBaseUrl(isWeb: true), 'http://localhost:3000/api');
    expect(resolveApiBaseUrl(isWeb: false), 'http://10.0.2.2:3000/api');
    expect(
      resolveApiBaseUrl(isWeb: true, override: 'https://x/api'),
      'https://x/api',
    );
  });

  test('get, post, put and delete send the token and return JSON', () async {
    tokens.token = 'abc';
    final api = client((r) => (200, {'method': r.method}));

    expect(await api.get('/films', query: {'page': 1}), {'method': 'GET'});
    expect(await api.post('/films/1/like'), {'method': 'POST'});
    expect(await api.put('/admin/settings', data: {}), {'method': 'PUT'});
    expect(await api.delete('/comments/1'), {'method': 'DELETE'});

    expect(sent.first.queryParameters, {'page': 1});
    expect(
      sent.every((r) => r.headers['Authorization'] == 'Bearer abc'),
      isTrue,
    );
  });

  test('a guest sends no token', () async {
    await client((_) => (200, {})).get('/films');
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test('a server error becomes its code and message', () async {
    final api = client(
      (_) => (
        402,
        {
          'error': {
            'code': 'INSUFFICIENT_COINS',
            'message': 'Not enough coins',
          },
        },
      ),
    );
    await expectLater(
      api.post('/episodes/1/unlock'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'INSUFFICIENT_COINS')
            .having((e) => e.statusCode, 'status', 402),
      ),
    );
  });

  test('no connection and odd answers become readable errors', () async {
    await expectLater(
      client((_) => (0, null)).get('/films'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
      ),
    );
    await expectLater(
      client((_) => (500, 'Bad gateway')).get('/films'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'UNKNOWN_ERROR'),
      ),
    );
    // Text with a success status is not our API either.
    await expectLater(
      client((_) => (200, '<html>')).get('/films'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'UNKNOWN_ERROR'),
      ),
    );
  });

  test('a refused token is cleared and the app is told', () async {
    tokens.token = 'old';
    var told = 0;
    final api = client(
      (_) => (
        401,
        {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'Expired'},
        },
      ),
      onUnauthorized: () => told++,
    );
    await expectLater(api.get('/wallet'), throwsA(isA<ApiException>()));
    expect(tokens.token, isNull);
    expect(told, 1);
  });

  test('a wrong password at login keeps the stored token', () async {
    tokens.token = 'kept';
    var told = 0;
    final api = client(
      (_) => (
        401,
        {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'Wrong password'},
        },
      ),
      onUnauthorized: () => told++,
    );
    await expectLater(
      api.post('/auth/login', data: {}),
      throwsA(isA<ApiException>()),
    );
    expect(tokens.token, 'kept');
    expect(told, 0);
  });

  test('an answer for a session that ended is dropped', () async {
    tokens.token = 'abc';
    final reply = Completer<void>();
    // Holds the answer back until the test lets it through.
    final dio = fakeDio(sent, (_) => (200, {'balance': 80}))
      ..interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) async {
            await reply.future;
            handler.next(response);
          },
        ),
      );
    final api = ApiClient(tokens: tokens, dio: dio);
    final pending = api.get('/wallet');
    await Future<void>.delayed(Duration.zero);
    api.beginNewSession();
    reply.complete();
    await expectLater(
      pending,
      throwsA(predicate((Object e) => isStaleSession(e))),
    );
    expect(api.generation, 1);
  });

  test('errorMessage shows API messages and hides anything else', () {
    expect(
      errorMessage(const ApiException(code: 'X', message: 'Shown')),
      'Shown',
    );
    expect(
      errorMessage(StateError('secret')),
      'Something went wrong. Please try again.',
    );
  });
}
