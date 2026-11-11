import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shortreel/services/token_store.dart';

/// What the fake server answers for one request: a status and a body (a map
/// or list is sent as JSON, a string as plain text, null as no response).
typedef FakeAnswer = (int, Object?) Function(RequestOptions request);

/// A [Dio] that never touches the network: [answer] decides every reply and
/// [sent] records each request after the interceptors ran.
Dio fakeDio(List<RequestOptions> sent, FakeAnswer answer) =>
    Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = _Adapter(sent, answer);

class _Adapter implements HttpClientAdapter {
  _Adapter(this._sent, this._answer);

  final List<RequestOptions> _sent;
  final FakeAnswer _answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _sent.add(options);
    final (status, body) = _answer(options);
    if (status == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final isText = body is String;
    return ResponseBody.fromString(
      isText ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          isText ? 'text/plain' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Keeps the login token in memory.
class MemoryTokens implements TokenStore {
  MemoryTokens([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}
