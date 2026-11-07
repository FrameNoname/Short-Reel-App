import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_store.dart';

String resolveApiBaseUrl({required bool isWeb, String override = ''}) {
  if (override.isNotEmpty) return override;
  return isWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';
}

final apiBaseUrl = resolveApiBaseUrl(
  isWeb: kIsWeb,
  override: const String.fromEnvironment('API_BASE_URL'),
);

/// Scheme, host and port of the API, for links the server returns as paths.
final apiOrigin = Uri.parse(apiBaseUrl).origin;

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Code of the [ApiException] thrown when an answer arrives after the person it
/// was asked for has logged out or been replaced by another login. The answer
/// is dropped; callers must not show it or apply it.
const staleSessionCode = 'STALE_SESSION';

bool isStaleSession(Object error) =>
    error is ApiException && error.code == staleSessionCode;

class ApiClient {
  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);

  ApiClient({required TokenStore tokens, Dio? dio, this.onUnauthorized})
    : _tokens = tokens,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              // A dead or slow network ends in an error the screen can show,
              // never in a spinner that turns forever. Video streams do not
              // go through here.
              connectTimeout: connectTimeout,
              receiveTimeout: receiveTimeout,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokens.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokens;
  int _generation = 0;

  /// Counts logins and logouts. A request that was sent with a token remembers
  /// the number it started under; if it has changed when the answer arrives,
  /// the answer belongs to someone else and is dropped.
  int get generation => _generation;

  /// Called whenever a different person (or nobody) becomes the signed-in user.
  void beginNewSession() => _generation++;

  /// Called when the server rejects a token the app sent (expired, or the
  /// account is gone), so the app can log the person out.
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => _dio.put<dynamic>(path, data: data));

  Future<dynamic> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    final startedUnder = _generation;
    try {
      final response = await request();
      final data = response.data;
      // Every endpoint speaks JSON, so text here came from something else.
      if (data is String && data.isNotEmpty) {
        throw ApiException(
          code: 'UNKNOWN_ERROR',
          message: 'The server sent an unexpected response',
          statusCode: response.statusCode,
        );
      }
      _dropIfStale(response.requestOptions, startedUnder);
      return data;
    } on DioException catch (e) {
      _dropIfStale(e.requestOptions, startedUnder);
      final error = _toApiException(e);
      final sentToken = e.requestOptions.headers.containsKey('Authorization');
      final isLoginAttempt = e.requestOptions.path.contains('/auth/login');
      if (error.statusCode == 401 && sentToken && !isLoginAttempt) {
        // A token the server refuses must stop being sent, or guest browsing
        // would fail too: the server rejects any bad token it is shown. Only
        // the token that is still the current one may be cleared.
        final current = await _tokens.read();
        final refused = e.requestOptions.headers['Authorization'];
        if (current != null && refused == 'Bearer $current') {
          await _tokens.clear();
          onUnauthorized?.call();
        } else {
          throw _stale();
        }
      }
      throw error;
    }
  }

  void _dropIfStale(RequestOptions options, int startedUnder) {
    final carriedIdentity = options.headers.containsKey('Authorization');
    if (carriedIdentity && startedUnder != _generation) throw _stale();
  }

  ApiException _stale() => const ApiException(
    code: staleSessionCode,
    message: 'The session changed while this request was running',
  );

  ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Cannot reach the server',
      );
    }
    final body = response.data;
    final error = body is Map ? body['error'] : null;
    if (error is Map && error['code'] is String && error['message'] is String) {
      return ApiException(
        code: error['code'] as String,
        message: error['message'] as String,
        statusCode: response.statusCode,
      );
    }
    return ApiException(
      code: 'UNKNOWN_ERROR',
      message: 'The server sent an unexpected response',
      statusCode: response.statusCode,
    );
  }
}
