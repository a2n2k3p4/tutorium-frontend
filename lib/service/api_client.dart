import 'dart:convert';

import 'package:http/http.dart' as http;

import 'Apiservice.dart';

/// Exception thrown when the Tutorium backend responds with a non-success status
/// code. The [statusCode] and (optional) [body] can be inspected by callers to
/// surface friendlier error messages.
class ApiException implements Exception {
  final int statusCode;
  final String? body;

  const ApiException(this.statusCode, [this.body]);

  @override
  String toString() {
    if (body == null || body!.isEmpty) {
      return 'ApiException(statusCode: $statusCode)';
    }
    return 'ApiException(statusCode: $statusCode, body: $body)';
  }
}

/// Lightweight HTTP client used by the service layer. It automatically builds
/// the base URL from `.env` via [ApiService.endpoint], decodes JSON responses,
/// and throws [ApiException] for non-2xx responses so callers only deal with
/// happy-path data structures.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = ApiService.endpoint(path, queryParameters: queryParameters);
    final response = await _client.get(uri, headers: headers);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final result = await get(
      path,
      queryParameters: queryParameters,
      headers: headers,
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    throw ApiException(
      200,
      'Expected a JSON object but received ${result.runtimeType}',
    );
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final result = await get(
      path,
      queryParameters: queryParameters,
      headers: headers,
    );
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    throw ApiException(
      200,
      'Expected a JSON array but received ${result.runtimeType}',
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = ApiService.endpoint(path, queryParameters: queryParameters);
    final response = await _client.post(
      uri,
      headers: _mergeJsonHeader(headers),
      body: _encodeBody(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJsonMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await post(
      path,
      queryParameters: queryParameters,
      headers: headers,
      body: body,
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    throw ApiException(
      201,
      'Expected a JSON object but received ${result.runtimeType}',
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = ApiService.endpoint(path, queryParameters: queryParameters);
    final response = await _client.put(
      uri,
      headers: _mergeJsonHeader(headers),
      body: _encodeBody(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> putJsonMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await put(
      path,
      queryParameters: queryParameters,
      headers: headers,
      body: body,
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    throw ApiException(
      200,
      'Expected a JSON object but received ${result.runtimeType}',
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = ApiService.endpoint(path, queryParameters: queryParameters);
    final response = await _client.delete(
      uri,
      headers: _mergeJsonHeader(headers),
      body: _encodeBody(body),
    );
    return _decodeResponse(response, allowEmpty: true);
  }

  Map<String, String> _mergeJsonHeader(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };
  }

  String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  dynamic _decodeResponse(http.Response response, {bool allowEmpty = false}) {
    final status = response.statusCode;
    final isSuccess = status >= 200 && status < 300;
    if (!isSuccess) {
      throw ApiException(status, response.body.isEmpty ? null : response.body);
    }

    if (response.body.isEmpty) {
      if (allowEmpty) return null;
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }
}
