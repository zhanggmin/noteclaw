import 'package:dio/dio.dart';

class BlinkoLoginResult {
  final String token;
  final Map<String, dynamic>? user;

  const BlinkoLoginResult({required this.token, this.user});
}

class BlinkoAuthService {
  BlinkoAuthService({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = (baseUrl ?? 'https://blinko.apidocumentation.com').replaceAll(RegExp(r'/+$'), '');

  final Dio _dio;
  final String _baseUrl;

  Future<BlinkoLoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/v1/user/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
      options: Options(
        headers: const {'Content-Type': 'application/json'},
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 0;
    final body = response.data;

    if (status < 200 || status >= 300) {
      final message = body is Map<String, dynamic>
          ? (body['message'] ?? body['error'] ?? 'Login failed')
          : 'Login failed';
      throw BlinkoAuthException('$message (HTTP $status)');
    }

    if (body is! Map<String, dynamic>) {
      throw const BlinkoAuthException('Login response format is invalid');
    }

    final token = (body['token'] ?? body['data']?['token'])?.toString();
    if (token == null || token.isEmpty) {
      throw const BlinkoAuthException('Login succeeded but token was missing');
    }

    final user = switch (body['user']) {
      Map<String, dynamic> v => v,
      _ => null,
    };

    return BlinkoLoginResult(token: token, user: user);
  }
}

class BlinkoAuthException implements Exception {
  final String message;

  const BlinkoAuthException(this.message);

  @override
  String toString() => 'BlinkoAuthException: $message';
}
