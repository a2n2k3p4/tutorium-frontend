import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/ban_status_service.dart';

/// Interceptor to handle 403 Forbidden responses (ban status)
class BanInterceptor extends Interceptor {
  final BuildContext? context;

  BanInterceptor({this.context});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if it's a 403 Forbidden response
    if (err.response?.statusCode == 403) {
      final data = err.response?.data;

      // Check if error message mentions suspension/ban
      if (data is Map<String, dynamic>) {
        final errorMessage = data['error']?.toString() ?? '';

        if (errorMessage.contains('suspended') ||
            errorMessage.contains('banned') ||
            errorMessage.contains('ระงับ')) {
          // Invalidate ban cache to force refresh
          final banService = BanStatusService();
          banService.clearCache();

          // Refresh ban status
          final banInfo = await banService.checkCurrentUserBanStatus();

          // Show ban dialog if context is available
          if (context != null && context!.mounted) {
            _showBanDialog(context!, banInfo, errorMessage);
          }

          // Return custom error
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: DioExceptionType.badResponse,
              error: 'Account suspended: $errorMessage',
            ),
          );
        }
      }
    }

    // Pass through other errors
    handler.next(err);
  }

  void _showBanDialog(
    BuildContext context,
    BanStatusInfo banInfo,
    String errorMessage,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'บัญชีถูกระงับ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
                      errorMessage,
                      style: TextStyle(color: Colors.red[900], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            if (banInfo.isBanned) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildInfoRow(
                'ประเภท',
                banInfo.roleType == 'learner' ? 'ผู้เรียน' : 'ครูผู้สอน',
                Icons.person,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'ระยะเวลาที่เหลือ',
                banInfo.formattedRemainingTime,
                Icons.timer,
              ),
              if (banInfo.reason != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('เหตุผล', banInfo.reason!, Icons.description),
              ],
            ],
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
                  Expanded(
                    child: Text(
                      'คุณสามารถใช้งานได้อีกครั้งเมื่อหมดระยะเวลาระงับ',
                      style: TextStyle(color: Colors.blue[900], fontSize: 13),
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
              // Optionally navigate to home or profile
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
