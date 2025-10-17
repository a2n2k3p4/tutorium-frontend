import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  final int userId;

  const PaymentScreen({super.key, required this.userId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum PaymentStatus { idle, creating, pending, success, failed, timeout }

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late final String backendUrl;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  PaymentStatus _status = PaymentStatus.idle;
  String _statusMessage = 'พร้อมสำหรับการสร้างคำสั่งชำระเงิน';
  String? _chargeId;
  String? _errorDetails;
  Timer? _pollingTimer;
  int _pollingCount = 0;
  static const int _maxPollingAttempts = 100; // 100 * 3 sec = 5 minutes
  String? _qrCodeUrl;

  @override
  void initState() {
    super.initState();
    backendUrl =
        '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}' ??
        'http://10.0.2.2:8080';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- helpers ---

  void _updateStatus(
    PaymentStatus status,
    String message, {
    String? errorDetails,
  }) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _statusMessage = message;
      _errorDetails = errorDetails;
    });
  }

  void _startPolling() {
    _pollingCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollingCount++;
      if (_pollingCount > _maxPollingAttempts) {
        timer.cancel();
        _updateStatus(
          PaymentStatus.timeout,
          'หมดเวลารอการชำระเงิน (5 นาที)',
          errorDetails: 'กรุณาสร้างคำสั่งชำระเงินใหม่',
        );
        return;
      }
      _checkPaymentStatus(isAutoPolling: true);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingCount = 0;
  }

  Future<void> _processPayment(Map<String, dynamic> payload) async {
    _stopPolling();
    _updateStatus(PaymentStatus.creating, 'กำลังสร้างคำสั่งชำระเงิน...');

    try {
      payload['user_id'] = widget.userId;

      final res = await http
          .post(
            Uri.parse('$backendUrl/payments/charge'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'การเชื่อมต่อหมดเวลา กรุณาลองใหม่อีกครั้ง',
              );
            },
          );

      final body = json.decode(res.body);

      // Handle error responses
      if (res.statusCode != 200) {
        final errorMsg =
            body['error'] ?? body['message'] ?? 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์';
        _updateStatus(
          PaymentStatus.failed,
          'การสร้างคำสั่งชำระเงินล้มเหลว',
          errorDetails: errorMsg,
        );
        return;
      }

      // Parse charge ID and QR code
      _chargeId = body['charge_id'] ?? body['id'];
      _qrCodeUrl = body['qr_code_url'];

      if (_chargeId == null || _chargeId!.isEmpty) {
        _updateStatus(
          PaymentStatus.failed,
          'ไม่พบรหัสคำสั่งชำระเงิน',
          errorDetails: 'Response: ${json.encode(body)}',
        );
        return;
      }

      // Check if already paid
      final isPaid = body['paid'] == true;
      if (isPaid) {
        _updateStatus(PaymentStatus.success, 'ชำระเงินสำเร็จแล้ว!');
        _navigateBackWithSuccess();
        return;
      }

      // Start polling for payment status
      _updateStatus(
        PaymentStatus.pending,
        'รอการชำระเงิน',
        errorDetails: 'Charge ID: $_chargeId',
      );
      _startPolling();
    } on TimeoutException catch (e) {
      _updateStatus(
        PaymentStatus.failed,
        'หมดเวลาการเชื่อมต่อ',
        errorDetails: e.message ?? 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต',
      );
    } catch (e) {
      _updateStatus(
        PaymentStatus.failed,
        'เกิดข้อผิดพลาด',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _checkPaymentStatus({bool isAutoPolling = false}) async {
    if (_chargeId == null || _chargeId!.isEmpty) {
      if (!isAutoPolling) {
        _updateStatus(
          PaymentStatus.failed,
          'ยังไม่มีคำสั่งชำระเงิน',
          errorDetails: 'กรุณาสร้างคำสั่งชำระเงินก่อน',
        );
      }
      return;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/webhooks/omise'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': _chargeId, 'object': 'charge'}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('หมดเวลาตรวจสอบสถานะ'),
          );

      final body = json.decode(res.body);

      if (res.statusCode == 200) {
        final isPaid = body['paid'] == true;

        if (isPaid) {
          _stopPolling();
          _updateStatus(PaymentStatus.success, 'ชำระเงินสำเร็จ!');
          _navigateBackWithSuccess();
        } else if (!isAutoPolling) {
          // Manual check but not paid yet
          _updateStatus(
            PaymentStatus.pending,
            'ยังไม่ได้รับการชำระเงิน',
            errorDetails: 'สถานะ: ${body['status'] ?? 'pending'}',
          );
        }
      } else {
        if (!isAutoPolling) {
          _updateStatus(
            PaymentStatus.failed,
            'ตรวจสอบสถานะไม่สำเร็จ',
            errorDetails:
                'HTTP ${res.statusCode}: ${body['error'] ?? res.body}',
          );
        }
      }
    } on TimeoutException catch (e) {
      if (!isAutoPolling) {
        _updateStatus(
          PaymentStatus.failed,
          'หมดเวลาการเชื่อมต่อ',
          errorDetails: e.message,
        );
      }
    } catch (e) {
      if (!isAutoPolling) {
        _updateStatus(
          PaymentStatus.failed,
          'เกิดข้อผิดพลาด',
          errorDetails: e.toString(),
        );
      }
    }
  }

  void _navigateBackWithSuccess() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _submitPayment() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    final rawInput = _amountController.text.replaceAll(',', '').trim();
    final amountDouble = double.tryParse(rawInput);

    if (amountDouble == null || amountDouble <= 0) {
      _updateStatus(
        PaymentStatus.failed,
        'จำนวนเงินไม่ถูกต้อง',
        errorDetails: 'กรุณากรอกจำนวนเงินที่ถูกต้อง',
      );
      return;
    }

    final amountSatang = (amountDouble * 100).round();

    await _processPayment({
      'amount': amountSatang,
      'currency': 'THB',
      'paymentType': 'promptpay',
      'description': 'เติมเงินเข้ากระเป๋า Tutorium',
      'metadata': {
        'source': 'wallet_topup',
        'display_amount': rawInput,
        'user_id': widget.userId,
      },
    });
  }

  void _resetPayment() {
    _stopPolling();
    setState(() {
      _status = PaymentStatus.idle;
      _statusMessage = 'พร้อมสำหรับการสร้างคำสั่งชำระเงิน';
      _chargeId = null;
      _errorDetails = null;
      _qrCodeUrl = null;
      _pollingCount = 0;
    });
  }

  Widget _buildStatusCard() {
    Color statusColor;
    Color bgColor;
    IconData statusIcon;
    String statusTitle;

    switch (_status) {
      case PaymentStatus.creating:
        statusColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        statusIcon = Icons.hourglass_empty_rounded;
        statusTitle = 'กำลังสร้างคำสั่งชำระเงิน...';
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        statusIcon = Icons.schedule_rounded;
        statusTitle = 'รอการชำระเงิน';
        break;
      case PaymentStatus.success:
        statusColor = Colors.green;
        bgColor = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'ชำระเงินสำเร็จ!';
        break;
      case PaymentStatus.failed:
        statusColor = Colors.red;
        bgColor = Colors.red.shade50;
        statusIcon = Icons.error_rounded;
        statusTitle = 'เกิดข้อผิดพลาด';
        break;
      case PaymentStatus.timeout:
        statusColor = Colors.grey;
        bgColor = Colors.grey.shade50;
        statusIcon = Icons.timer_off_rounded;
        statusTitle = 'หมดเวลา';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status icon with animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 48, color: statusColor),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Status title
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),

          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),

          // Charge ID (if available)
          if (_chargeId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Charge ID: $_chargeId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],

          // Error details (if available)
          if (_errorDetails != null && _errorDetails!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorDetails!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Polling indicator (if pending)
          if (_status == PaymentStatus.pending) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ตรวจสอบอัตโนมัติทุก 3 วินาที (${_pollingCount}/${_maxPollingAttempts})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],

          // Action buttons
          if (_status == PaymentStatus.pending ||
              _status == PaymentStatus.failed ||
              _status == PaymentStatus.timeout) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                if (_status == PaymentStatus.pending)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _checkPaymentStatus(isAutoPolling: false),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('ตรวจสอบเลย'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: statusColor,
                        side: BorderSide(color: statusColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_status == PaymentStatus.failed ||
                    _status == PaymentStatus.timeout) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _resetPayment,
                      icon: const Icon(Icons.replay_rounded, size: 20),
                      label: const Text('ลองใหม่'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'เติมเงิน',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero card with wallet icon
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'เติมเงินเข้ากระเป๋า',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ชำระผ่าน PromptPay อย่างรวดเร็ว',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Amount input card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'จำนวนเงิน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 16, top: 12),
                              child: Text(
                                '฿',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF667eea),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'โปรดกรอกจำนวนเงิน';
                            }
                            final sanitized = value.replaceAll(',', '');
                            final parsed = double.tryParse(sanitized);
                            if (parsed == null) {
                              return 'จำนวนเงินไม่ถูกต้อง';
                            }
                            if (parsed <= 0) {
                              return 'จำนวนเงินต้องมากกว่า 0 บาท';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Quick amount buttons
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [50, 100, 200, 500, 1000].map((amount) {
                            return InkWell(
                              onTap: () =>
                                  _amountController.text = amount.toString(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  '฿$amount',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_status == PaymentStatus.creating ||
                                    _status == PaymentStatus.pending)
                                ? null
                                : _submitPayment,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              disabledBackgroundColor: Colors.grey.shade300,
                            ),
                            child: _status == PaymentStatus.creating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.qr_code_2_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'สร้างคำสั่งชำระเงิน',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Status card
                if (_status != PaymentStatus.idle) _buildStatusCard(),
                const SizedBox(height: 16),
                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ชำระเงินผ่าน PromptPay แล้วกดปุ่มตรวจสอบสถานะเพื่ออัพเดทยอดเงิน',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
