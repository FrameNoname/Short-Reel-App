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

class ApiClient {
  ApiClient({required TokenStore tokens, Dio? dio, this.onUnauthorized})
    : _tokens = tokens,
      _dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl)) {
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
      return data;
    } on DioException catch (e) {
      final error = _toApiException(e);
      final sentToken =
          e.requestOptions.headers.containsKey('Authorization');
      final isLoginAttempt = e.requestOptions.path.contains('/auth/login');
      if (error.statusCode == 401 && sentToken && !isLoginAttempt) {
        // A token the server refuses must stop being sent, or guest browsing
        // would fail too: the server rejects any bad token it is shown.
        await _tokens.clear();
        onUnauthorized?.call();
      }
      throw error;
    }
  }

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
