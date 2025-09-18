import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class BaseApiService {
  static const String _tokenKey = 'auth_token';
  static const Duration _defaultTimeout = Duration(seconds: 20);

  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Remove token
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Get headers with authorization
  Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // GET request
  Future<http.Response> get(String endpoint, {bool includeAuth = true}) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _logRequest('GET', url.toString(), headers: headers);
    try {
      final res = await http.get(url, headers: headers).timeout(_defaultTimeout);
      _logResponse('GET', url.toString(), res);
      return res;
    } on TimeoutException {
      throw ApiException(408, {'error': 'Request timeout'});
    } on SocketException catch (e) {
      throw ApiException(503, {'error': 'Network error', 'detail': e.message});
    }
  }

  // POST request
  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _logRequest('POST', url.toString(), headers: headers, body: body);
    try {
      final res = await http
          .post(url, headers: headers, body: json.encode(body))
          .timeout(_defaultTimeout);
      _logResponse('POST', url.toString(), res);
      return res;
    } on TimeoutException {
      throw ApiException(408, {'error': 'Request timeout'});
    } on SocketException catch (e) {
      throw ApiException(503, {'error': 'Network error', 'detail': e.message});
    }
  }

  // PUT request
  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _logRequest('PUT', url.toString(), headers: headers, body: body);
    try {
      final res = await http
          .put(url, headers: headers, body: json.encode(body))
          .timeout(_defaultTimeout);
      _logResponse('PUT', url.toString(), res);
      return res;
    } on TimeoutException {
      throw ApiException(408, {'error': 'Request timeout'});
    } on SocketException catch (e) {
      throw ApiException(503, {'error': 'Network error', 'detail': e.message});
    }
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    final headers = await getHeaders(includeAuth: includeAuth);
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _logRequest('DELETE', url.toString(), headers: headers);
    try {
      final res = await http
          .delete(url, headers: headers)
          .timeout(_defaultTimeout);
      _logResponse('DELETE', url.toString(), res);
      return res;
    } on TimeoutException {
      throw ApiException(408, {'error': 'Request timeout'});
    } on SocketException catch (e) {
      throw ApiException(503, {'error': 'Network error', 'detail': e.message});
    }
  }

  // Handle API response
  Map<String, dynamic> handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body);
        } on FormatException {
          return {'raw': response.body};
        }
      }
      return {'success': true};
    } else {
      Map<String, dynamic> payload = {'error': 'Unknown error'};
      if (response.body.isNotEmpty) {
        try {
          payload = json.decode(response.body);
        } on FormatException {
          payload = {'raw': response.body};
        }
      }
      throw ApiException(response.statusCode, payload);
    }
  }

  // Handle list response
  List<dynamic> handleListResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          final decoded = json.decode(response.body);
          if (decoded == null) return [];
          if (decoded is List) return decoded;
          return [decoded];
        } on FormatException {
          return [];
        }
      }
      return [];
    } else {
      Map<String, dynamic> payload = {'error': 'Unknown error'};
      if (response.body.isNotEmpty) {
        try {
          payload = json.decode(response.body);
        } on FormatException {
          payload = {'raw': response.body};
        }
      }
      throw ApiException(response.statusCode, payload);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic> error;

  ApiException(this.statusCode, this.error);

  @override
  String toString() {
    return 'API Error $statusCode: ${error.toString()}';
  }
}

// Simple console logger for HTTP requests
void _logRequest(
  String method,
  String url, {
  Map<String, String>? headers,
  Map<String, dynamic>? body,
}) {
  // Hide Authorization for safety
  final safeHeaders = (headers ?? {})
      .map((k, v) => MapEntry(k, k.toLowerCase() == 'authorization' ? '***' : v));
  final bodyPreview = body == null ? '' : json.encode(body);
  final truncatedBody = bodyPreview.length > 200
      ? '${bodyPreview.substring(0, 200)}...'
      : bodyPreview;
  // Print concise request log
  // Example: [HTTP] POST http://host/route headers={...} body={...}
  // ignore: avoid_print
  print('[HTTP] $method $url headers=$safeHeaders body=$truncatedBody');
}

void _logResponse(String method, String url, http.Response res) {
  final preview = res.body.isNotEmpty ? res.body : '';
  final truncated = preview.length > 300 ? '${preview.substring(0, 300)}...' : preview;
  // ignore: avoid_print
  print('[HTTP] $method $url -> ${res.statusCode} ${res.reasonPhrase} body=$truncated');
}
