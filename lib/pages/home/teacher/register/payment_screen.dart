import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  final int userId;

  const PaymentScreen({super.key, required this.userId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late final String backendUrl;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _paymentSuccess = false;
  String _message = 'พร้อมสำหรับการสร้างคำสั่งชำระเงิน';
  String? _chargeId;

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
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- helpers ---

  Future<void> _setStatus(String msg, {bool loading = false, bool success = false}) async {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _isLoading = loading;
      _paymentSuccess = success;
    });
  }

  Future<void> _processPayment(Map<String, dynamic> payload) async {
    setState(() {
      _isLoading = true;
      _message = 'Processing payment...';
      _chargeId = null;
    });

    try {
      // Add user_id to all requests
      payload['user_id'] = widget.userId;

      final res = await http.post(
        Uri.parse('$backendUrl/payments/charge'), // Updated endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final body = json.decode(res.body);
      if (res.statusCode != 200) {
        await _setStatus('Payment failed: ${body['error'] ?? 'Server error'}');
        return;
      }

      // Handle different response formats based on payment type
      if (body['type'] == 'credit_card') {
        _chargeId = body['charge_id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';
        final authorized = body['authorized'] == true;

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        if (authorized) summary.write(' (authorized)');
        await _setStatus(summary.toString());
      } else if (body['type'] == 'promptpay') {
        _chargeId = body['charge_id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';

        final summary = StringBuffer(
          'รายการ ${_chargeId ?? '-'} สถานะ: $status',
        );
        await _setStatus(summary.toString());
      } else if (body['type'] == 'truemoney' ||
          body['type'] == 'internet_banking') {
        _chargeId = body['charge_id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        await _setStatus(summary.toString());
      } else {
        // Fallback to original Omise response parsing
        _chargeId = body['id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';
        final paid = body['paid'] == true;

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        if (paid) summary.write(' (paid)');

        await _setStatus(summary.toString());
      }
    } catch (e) {
      await _setStatus('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_chargeId == null || _chargeId!.isEmpty) {
      await _setStatus('ยังไม่มีคำสั่งชำระเงินให้ตรวจสอบ');
      return;
    }

    await _setStatus('กำลังตรวจสอบสถานะการชำระเงิน...', loading: true);
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/webhooks/omise'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': _chargeId, 'object': 'charge'}),
      );

      if (res.statusCode == 200) {
        await _setStatus('การชำระเงินสำเร็จ!', success: true);

        // Pop back immediately with success flag
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        await _setStatus(
          'ตรวจสอบสถานะไม่สำเร็จ (${res.statusCode}): ${res.body}',
        );
      }
    } catch (e) {
      await _setStatus('เกิดข้อผิดพลาดระหว่างตรวจสอบสถานะ: $e');
    }
  }

  Future<void> _submitPayment() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    FocusScope.of(context).unfocus();

    final rawInput = _amountController.text.replaceAll(',', '').trim();
    final amountDouble = double.tryParse(rawInput);
    if (amountDouble == null) {
      await _setStatus('Please enter a valid amount');
      return;
    }

    final amountSatang = (amountDouble * 100).round();
    if (amountSatang <= 0) {
      await _setStatus('Amount must be greater than zero');
      return;
    }

    await _processPayment({
      'amount': amountSatang,
      'currency': 'THB',
      'paymentType': 'promptpay',
      'description': 'Tutorium teacher registration payment',
      'metadata': {
        'source': 'teacher_registration',
        'display_amount': rawInput,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'เติมเงิน',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
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
                              onTap: () => _amountController.text = amount.toString(),
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
                            onPressed: _isLoading ? null : _submitPayment,
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
                            child: _isLoading
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
                if (_chargeId != null)
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
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _paymentSuccess
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _paymentSuccess
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 40,
                            color: _paymentSuccess
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _paymentSuccess
                              ? 'ชำระเงินสำเร็จ!'
                              : 'รอการชำระเงิน',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _paymentSuccess
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!_paymentSuccess) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _checkPaymentStatus,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text(
                                'ตรวจสอบสถานะ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                foregroundColor: const Color(0xFF667eea),
                                side: const BorderSide(
                                  color: Color(0xFF667eea),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
