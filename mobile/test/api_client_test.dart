import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body, {this.contentType = 'application/json'});

  final int status;
  final String body;
  final String contentType;
  Object? failure;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (failure != null) throw failure!;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient clientWith(FakeAdapter adapter, {String? token}) {
  return ApiClient(
    tokens: MemoryTokenStore(token),
    dio: Dio()..httpClientAdapter = adapter,
  );
}

void main() {
  test('attaches the stored token', () async {
    final adapter = FakeAdapter(200, '{}');
    await clientWith(adapter, token: 'abc').get('/wallet');
    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer abc');
  });

  test('sends no header for guests', () async {
    final adapter = FakeAdapter(200, '{}');
    await clientWith(adapter).get('/films');
    expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('maps the shared error format', () async {
    final body = jsonEncode({
      'error': {'code': 'FORBIDDEN', 'message': 'No access'},
    });
    await expectLater(
      clientWith(FakeAdapter(403, body)).get('/admin/users'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'FORBIDDEN')
            .having((e) => e.message, 'message', 'No access')
            .having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('handles non-JSON error bodies', () async {
    final adapter = FakeAdapter(
      502,
      '<html>Bad gateway</html>',
      contentType: 'text/html',
    );
    await expectLater(
      clientWith(adapter).get('/films'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'UNKNOWN_ERROR')
            .having((e) => e.statusCode, 'statusCode', 502),
      ),
    );
  });

  test('handles a connection failure', () async {
    final adapter = FakeAdapter(200, '{}')
      ..failure = DioException.connectionError(
        requestOptions: RequestOptions(path: '/films'),
        reason: 'refused',
      );
    await expectLater(
      clientWith(adapter).get('/films'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test('returns decoded JSON on success', () async {
    final result = await clientWith(
      FakeAdapter(200, '{"status":"ok"}'),
    ).get('/health');
    expect(result, {'status': 'ok'});
  });
}
