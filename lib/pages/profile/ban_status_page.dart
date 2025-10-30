import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/ban_status_service.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:intl/intl.dart';

/// Page to show user's ban and flag status
class BanStatusPage extends StatefulWidget {
  const BanStatusPage({super.key});

  @override
  State<BanStatusPage> createState() => _BanStatusPageState();
}

class _BanStatusPageState extends State<BanStatusPage> {
  final _banService = BanStatusService();
  BanStatusInfo? _banInfo;
  int _learnerFlagCount = 0;
  int _teacherFlagCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load ban status and flag counts in parallel
      final results = await Future.wait([
        _banService.checkCurrentUserBanStatus(),
        _banService.getLearnerFlagCount(),
        _loadTeacherFlagCount(),
      ]);

      if (mounted) {
        setState(() {
          _banInfo = results[0] as BanStatusInfo;
          _learnerFlagCount = results[1] as int;
          _teacherFlagCount = results[2] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาด: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<int> _loadTeacherFlagCount() async {
    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) return 0;

      // Assume teacher ID can be fetched from user cache or similar
      // For now, return 0
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('สถานะบัญชี'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanStatusCard(),
                    const SizedBox(height: 16),
                    _buildFlagStatusCard(),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'เกิดข้อผิดพลาด',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanStatusCard() {
    final isBanned = _banInfo?.isBanned ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isBanned
              ? LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBanned ? Icons.block : Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBanned ? 'บัญชีถูกระงับ' : 'บัญชีปกติ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBanned
                            ? 'ไม่สามารถใช้งานบางฟังก์ชันได้'
                            : 'สามารถใช้งานได้ปกติ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isBanned && _banInfo != null) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              _buildBanDetail(
                'ประเภท',
                _banInfo!.roleType == 'learner' ? 'ผู้เรียน' : 'ครูผู้สอน',
                Icons.person,
              ),
              const SizedBox(height: 12),
              _buildBanDetail(
                'สิ้นสุด',
                DateFormat('d MMM yyyy, HH:mm', 'th').format(_banInfo!.banEnd!),
                Icons.event,
              ),
              const SizedBox(height: 12),
              _buildBanDetail(
                'เหลือเวลา',
                _banInfo!.formattedRemainingTime,
                Icons.timer,
              ),
              if (_banInfo!.reason != null) ...[
                const SizedBox(height: 12),
                _buildBanDetail('เหตุผล', _banInfo!.reason!, Icons.description),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBanDetail(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlagStatusCard() {
    final totalFlags = _learnerFlagCount + _teacherFlagCount;
    final hasFlags = totalFlags > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasFlags ? Icons.flag : Icons.verified,
                  color: hasFlags
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'สถานะธง (Flags)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_learnerFlagCount > 0) ...[
              _buildFlagRow(
                'ผู้เรียน',
                _learnerFlagCount,
                Icons.school,
                Colors.blue,
              ),
              const SizedBox(height: 12),
            ],
            if (_teacherFlagCount > 0) ...[
              _buildFlagRow(
                'ครูผู้สอน',
                _teacherFlagCount,
                Icons.co_present,
                Colors.purple,
              ),
              const SizedBox(height: 12),
            ],
            if (!hasFlags) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'คุณไม่มีธงใดๆ ใช้งานได้ปกติ',
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasFlags) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'เมื่อมีธง 3 ธง จะถูกระงับบัญชี 7 วัน',
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlagRow(
    String label,
    int count,
    IconData icon,
    MaterialColor color,
  ) {
    final remaining = 3 - count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count / 3 ธง',
                style: TextStyle(
                  color: color.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: count / 3,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              count >= 2 ? Colors.red.shade600 : color.shade600,
            ),
          ),
        ),
        if (remaining > 0) ...[
          const SizedBox(height: 4),
          Text(
            'อีก $remaining ธงจะถูกระงับ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'ข้อมูลเพิ่มเติม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              'ธง (Flag) คืออะไร?',
              'ธงเป็นระบบเตือนสำหรับพฤติกรรมที่ไม่เหมาะสม เช่น ครูไม่เข้าสอน หรือผู้เรียนรบกวนการเรียน',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              'การระงับบัญชี',
              'เมื่อมีธง 3 ธง บัญชีจะถูกระงับ 7 วัน และนับ Ban Count เพิ่ม 1 ครั้ง',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              'ระยะเวลาระงับ',
              'ระหว่างถูกระงับ คุณจะไม่สามารถใช้งานฟีเจอร์บางอย่างได้ เช่น การสอน การเรียน',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
