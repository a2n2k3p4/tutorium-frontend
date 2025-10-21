import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/ban_status_service.dart';
import 'package:intl/intl.dart';

/// Banner widget to display ban status at the top of the screen
class BanStatusBanner extends StatefulWidget {
  const BanStatusBanner({super.key});

  @override
  State<BanStatusBanner> createState() => _BanStatusBannerState();
}

class _BanStatusBannerState extends State<BanStatusBanner> {
  final _banService = BanStatusService();
  BanStatusInfo? _banInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBanStatus();
  }

  Future<void> _checkBanStatus() async {
    setState(() => _isLoading = true);

    final info = await _banService.checkCurrentUserBanStatus();

    if (mounted) {
      setState(() {
        _banInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_banInfo == null || !_banInfo!.isBanned) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[700]!, Colors.red[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.block, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บัญชีของคุณถูกระงับ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'หมดเวลา: ${_formatBanEnd(_banInfo!.banEnd!)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      if (_banInfo!.formattedRemainingTime.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'เหลืออีก ${_banInfo!.formattedRemainingTime}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showBanDetails(context),
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  tooltip: 'ดูรายละเอียด',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBanEnd(DateTime banEnd) {
    final formatter = DateFormat('d MMM yyyy, HH:mm', 'th');
    return formatter.format(banEnd);
  }

  void _showBanDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text(
              'รายละเอียดการระงับบัญชี',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'ประเภท',
                _banInfo!.roleType == 'learner' ? 'ผู้เรียน' : 'ครูผู้สอน',
                Icons.person,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'เริ่มระงับ',
                _formatBanEnd(_banInfo!.banStart!),
                Icons.event,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'สิ้นสุดระงับ',
                _formatBanEnd(_banInfo!.banEnd!),
                Icons.event_available,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'เหลือเวลา',
                _banInfo!.formattedRemainingTime,
                Icons.timer,
              ),
              if (_banInfo!.reason != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.description, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เหตุผล',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _banInfo!.reason!,
                            style: TextStyle(
                              color: Colors.grey[900],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[700], size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(color: Colors.grey[900], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget to show flag count warning
class FlagCountWarning extends StatelessWidget {
  final int flagCount;
  final String roleType; // 'learner' or 'teacher'

  const FlagCountWarning({
    super.key,
    required this.flagCount,
    required this.roleType,
  });

  @override
  Widget build(BuildContext context) {
    if (flagCount == 0) return const SizedBox.shrink();

    final remainingFlags = 3 - flagCount;
    final isUrgent = flagCount >= 2;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red[300]! : Colors.orange[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning : Icons.flag,
            color: isUrgent ? Colors.red[700] : Colors.orange[700],
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent ? '⚠️ คำเตือนร้ายแรง' : 'แจ้งเตือน',
                  style: TextStyle(
                    color: isUrgent ? Colors.red[900] : Colors.orange[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'คุณมีธง (Flag) จำนวน $flagCount',
                  style: TextStyle(
                    color: isUrgent ? Colors.red[800] : Colors.orange[800],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUrgent
                      ? 'อีก $remainingFlags ธงจะถูกระงับบัญชี 7 วัน!'
                      : 'เมื่อถึง 3 ธง จะถูกระงับบัญชี 7 วัน',
                  style: TextStyle(
                    color: isUrgent ? Colors.red[700] : Colors.orange[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
