import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/Users.dart';

class LoginResponse {
  final String token;
  final User user;

  const LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] ?? '',
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class LoginService {
  static final ApiClient _client = ApiClient();

  /// POST /login (200, 400, 401, 500)
  static Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.postJsonMap(
      '/login',
      body: {'username': username, 'password': password},
    );
    return LoginResponse.fromJson(response);
  }
}
