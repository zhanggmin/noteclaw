import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class BlinkoLoginResult {
  final String token;
  final Map<String, dynamic>? user;

  const BlinkoLoginResult({required this.token, this.user});
}

class BlinkoAuthService {
  BlinkoAuthService({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _baseUrl = normalizeBaseUrl(baseUrl ?? defaultBaseUrl);

  final Dio _dio;
  final String _baseUrl;

  static const defaultBaseUrl = 'http://127.0.0.1:1111';

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final withoutTrailingSlash = trimmed.replaceAll(RegExp(r'/+$'), '');
    if (withoutTrailingSlash.endsWith('/api/v1')) {
      return withoutTrailingSlash.substring(
        0,
        withoutTrailingSlash.length - '/api/v1'.length,
      );
    }
    return withoutTrailingSlash;
  }

  Future<BlinkoLoginResult> login({
    required String name,
    required String password,
  }) async {
    final url = '$_baseUrl/api/v1/user/login';
    final requestData = {'name': name.trim(), 'password': password};
    if (kDebugMode) {
      debugPrint('[BlinkoAuth] POST $url');
      debugPrint('[BlinkoAuth] request: ${_redactRequest(requestData)}');
    }

    final Response<dynamic> response;
    try {
      response = await _dio.post(
        url,
        data: requestData,
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw BlinkoAuthException(_formatDioError(e, url));
    }

    final status = response.statusCode ?? 0;
    final body = response.data;
    if (kDebugMode) {
      debugPrint('[BlinkoAuth] response status: $status');
      debugPrint('[BlinkoAuth] response body: $body');
    }

    if (status < 200 || status >= 300) {
      final message = body is Map<String, dynamic>
          ? (body['message'] ?? body['error'] ?? 'Login failed')
          : 'Login failed';
      throw BlinkoAuthException('$message (HTTP $status)');
    }

    if (body is! Map<String, dynamic>) {
      throw const BlinkoAuthException('Login response format is invalid');
    }

    final token = _extractToken(body);
    if (token == null || token.isEmpty) {
      throw const BlinkoAuthException('Login succeeded but token was missing');
    }

    final user = switch (body['user']) {
      Map<String, dynamic> v => v,
      _ => null,
    };

    return BlinkoLoginResult(token: token, user: user);
  }

  String? _extractToken(Map<String, dynamic> body) {
    final data = body['data'];
    final response = body['response'];
    final candidates = [
      body['token'],
      body['accessToken'],
      body['access_token'],
      if (data is Map<String, dynamic>) data['token'],
      if (data is Map<String, dynamic>) data['accessToken'],
      if (data is Map<String, dynamic>) data['access_token'],
      if (response is Map<String, dynamic>) response['token'],
      if (response is Map<String, dynamic>) response['accessToken'],
      if (response is Map<String, dynamic>) response['access_token'],
    ];
    for (final candidate in candidates) {
      final token = candidate?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Map<String, dynamic> _redactRequest(Map<String, dynamic> data) {
    return {...data, if (data.containsKey('password')) 'password': '***'};
  }

  String _formatDioError(DioException e, String url) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final statusText = status == null ? '' : ' HTTP $status.';
    final bodyText = body == null ? '' : ' Response: $body';
    return 'Request failed: ${e.message ?? e.type.name}.$statusText URL: $url.$bodyText';
  }
}

class BlinkoAuthException implements Exception {
  final String message;

  const BlinkoAuthException(this.message);

  @override
  String toString() => 'BlinkoAuthException: $message';
}
