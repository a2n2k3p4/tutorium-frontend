import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/ban_status_service.dart';

/// Enhanced API client that handles ban status (403 errors)
class BanAwareApiClient extends ApiClient {
  final BuildContext? context;
  final VoidCallback? onBanned;

  BanAwareApiClient({this.context, this.onBanned, super.httpClient});

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      return await super.get(
        path,
        queryParameters: queryParameters,
        headers: headers,
      );
    } on ApiException catch (e) {
      _handleBanException(e);
      rethrow;
    }
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await super.post(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );
    } on ApiException catch (e) {
      _handleBanException(e);
      rethrow;
    }
  }

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await super.put(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );
    } on ApiException catch (e) {
      _handleBanException(e);
      rethrow;
    }
  }

  @override
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await super.delete(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );
    } on ApiException catch (e) {
      _handleBanException(e);
      rethrow;
    }
  }

  void _handleBanException(ApiException e) {
    if (e.statusCode == 403 && e.body != null) {
      try {
        final body = jsonDecode(e.body!);
        final error = body['error']?.toString() ?? '';

        if (error.contains('suspended') ||
            error.contains('banned') ||
            error.contains('ระงับ')) {
          // Invalidate cache
          BanStatusService().clearCache();

          // Call callback if provided
          onBanned?.call();

          // Show dialog if context available
          if (context != null && context!.mounted) {
            _showBanDialog(context!, error);
          }
        }
      } catch (_) {
        // Ignore JSON parse errors
      }
    }
  }

  void _showBanDialog(BuildContext context, String message) {
    // Check if there's already a dialog showing
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('บัญชีถูกระงับ', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: Colors.red[900], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ดูรายละเอียดเพิ่มเติมในหน้าโปรไฟล์',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to ban status page
              Navigator.of(context).pushNamed('/ban-status');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ดูรายละเอียด'),
          ),
        ],
      ),
    );
  }
}

/// Helper function to create ban-aware API client
BanAwareApiClient createBanAwareClient({
  BuildContext? context,
  VoidCallback? onBanned,
}) {
  return BanAwareApiClient(context: context, onBanned: onBanned);
}
