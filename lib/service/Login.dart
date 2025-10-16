import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class LoginResponse {
  final String token;
  final Map<String, dynamic> user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(token: json['token'], user: json['user']);
  }
}

class LoginService {
  /// POST /login (200, 400, 401, 500)
  static Future<LoginResponse> login(Map<String, dynamic> body) async {
    final res = await http.post(
      ApiService.endpoint("/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    switch (res.statusCode) {
      case 200:
        return LoginResponse.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 401:
        throw Exception("Unauthorized: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Login failed (code: ${res.statusCode})");
    }
  }
}
