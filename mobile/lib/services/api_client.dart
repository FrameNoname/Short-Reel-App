import 'package:dio/dio.dart';

import 'token_store.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api',
);

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
  ApiClient({required TokenStore tokens, Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl)) {
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
      return (await request()).data;
    } on DioException catch (e) {
      throw _toApiException(e);
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
