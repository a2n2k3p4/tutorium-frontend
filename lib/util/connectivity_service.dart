import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// ConnectivityService - ตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแบบ real-time
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controller สำหรับแจ้งเตือนสถานะการเชื่อมต่อ
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// เริ่มต้นการตรวจสอบการเชื่อมต่อ
  Future<void> initialize() async {
    // ตรวจสอบสถานะการเชื่อมต่อเริ่มต้น
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // ติดตามการเปลี่ยนแปลงของสถานะการเชื่อมต่อ
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _updateConnectionStatus(result);
    });
  }

  /// อัพเดทสถานะการเชื่อมต่อ
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // ถือว่าเชื่อมต่อได้ถ้ามีอย่างน้อย 1 ช่องทางที่ไม่ใช่ none
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      _connectionStatusController.add(_isConnected);

      debugPrint(
        'DEBUG ConnectivityService: Connection status changed - isConnected=$_isConnected',
      );
      debugPrint('DEBUG ConnectivityService: Connection types: $results');
    }
  }

  /// ตรวจสอบการเชื่อมต่อปัจจุบัน
  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    final hasConnection = result.any(
      (result) => result != ConnectivityResult.none,
    );
    return hasConnection;
  }

  /// ปิดการทำงาน
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStatusController.close();
  }
}

/// NoInternetBanner - Widget แสดงแบนเนอร์เมื่อไม่มีอินเทอร์เน็ต
class NoInternetBanner extends StatelessWidget {
  const NoInternetBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red[700],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ConnectivityWrapper - Wrapper widget ที่แสดงแบนเนอร์เมื่อไม่มีเน็ต
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnect;

  const ConnectivityWrapper({super.key, required this.child, this.onReconnect});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // ตรวจสอบสถานะเริ่มต้น
    _isConnected = await _connectivityService.checkConnection();

    if (mounted) {
      setState(() {});
    }

    // ฟังการเปลี่ยนแปลงสถานะ
    _connectivityService.connectionStatus.listen((isConnected) {
      if (mounted) {
        final wasDisconnected = !_isConnected;
        setState(() {
          _isConnected = isConnected;
        });

        // แสดง SnackBar เมื่อสถานะเปลี่ยน และเรียก refresh callback
        if (isConnected && wasDisconnected) {
          // เรียก refresh callback เมื่อเน็ตกลับมา
          widget.onReconnect?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'กลับมาเชื่อมต่ออินเทอร์เน็ตแล้ว กำลังโหลดข้อมูลใหม่...',
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isConnected) const NoInternetBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}
