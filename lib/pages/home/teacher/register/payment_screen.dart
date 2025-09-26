import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final int userId; // Add userId parameter

  const PaymentScreen({super.key, required this.userId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final String backendUrl;
  late final String publicKey;
  late final String returnUri;

  bool _isLoading = false;
  String _message = 'Ready to process payments';
  String? _qrUrl; // for PromptPay QR
  String? _authorizeUri; // for internet banking redirect
  String? _chargeId; // for display/potential polling/debug

  @override
  void initState() {
    super.initState();
    backendUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}' ?? 'http://10.0.2.2:8080';
    publicKey = dotenv.env['OMISE_PUBLIC_KEY'] ?? '';
    returnUri = dotenv.env['RETURN_URI'] ?? 'https://example.com/complete';
  }

  // --- helpers ---

  Future<void> _setStatus(String msg, {bool loading = false}) async {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _isLoading = loading;
    });
  }

  Future<void> _processPayment(Map<String, dynamic> payload) async {
    setState(() {
      _isLoading = true;
      _message = 'Processing payment...';
      _qrUrl = null;
      _authorizeUri = null;
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
        _qrUrl = body['qr_image'] as String?;

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        if (_qrUrl != null) summary.write('\nShow QR and ask user to pay.');
        await _setStatus(summary.toString());
      } else if (body['type'] == 'truemoney' ||
          body['type'] == 'internet_banking') {
        _chargeId = body['charge_id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';
        _authorizeUri = body['authorize_uri'] as String?;

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        if (_authorizeUri != null)
          summary.write('\nNeeds authorization in browser.');
        await _setStatus(summary.toString());
      } else {
        // Fallback to original Omise response parsing
        _chargeId = body['id'] as String?;
        final status = (body['status'] as String?) ?? 'unknown';
        final paid = body['paid'] == true;
        final authorizeUri = body['authorize_uri'] as String?;
        final source = body['source'] as Map<String, dynamic>?;

        // PromptPay QR (source.scannable_code.image.download_uri)
        String? qr;
        if (source != null) {
          final scannable = source['scannable_code'] as Map<String, dynamic>?;
          final image = scannable?['image'] as Map<String, dynamic>?;
          qr = image?['download_uri'] as String?;
        }

        setState(() {
          _authorizeUri = authorizeUri;
          _qrUrl = qr;
        });

        final summary = StringBuffer(
          'Charge ${_chargeId ?? ''} → status: $status',
        );
        if (paid) summary.write(' (paid)');
        if (_authorizeUri != null)
          summary.write('\nNeeds authorization in browser.');
        if (_qrUrl != null) summary.write('\nShow QR and ask user to pay.');

        await _setStatus(summary.toString());
      }
    } catch (e) {
      await _setStatus('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Create a card token on Omise Vault with PUBLIC key (PCI-safe)
  Future<String> _createCardToken({
    required String name,
    required String number,
    required int expMonth,
    required int expYear,
    required String cvc,
    String city = 'Bangkok',
    String postalCode = '10320',
  }) async {
    if (publicKey.isEmpty) {
      throw StateError('OMISE_PUBLIC_KEY is missing in .env');
    }
    final auth = 'Basic ${base64Encode(utf8.encode('$publicKey:'))}';
    final res = await http.post(
      Uri.parse('https://vault.omise.co/tokens'),
      headers: {
        'Authorization': auth,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'card[name]': name,
        'card[number]': number,
        'card[expiration_month]': expMonth.toString(),
        'card[expiration_year]': expYear.toString(),
        'card[security_code]': cvc,
        'card[city]': city,
        'card[postal_code]': postalCode,
      },
    );
    if (res.statusCode != 200) {
      throw StateError('Token creation failed: ${res.statusCode} ${res.body}');
    }
    final tok = json.decode(res.body) as Map<String, dynamic>;
    final id = tok['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Invalid token response: ${res.body}');
    }
    return id;
  }

  // --- payment flows wired to your Go backend ---

  Future<void> _payWithCard() async {
    try {
      // 1) Create token on client (vault.omise.co) with PUBLIC key
      final token = await _createCardToken(
        name: 'John Doe',
        number: '4242424242424242',
        expMonth: 12,
        expYear: 2029,
        cvc: '123',
      );

      // 2) Send token to server for charging with SECRET key
      await _processPayment({
        'amount': 100000, // THB 1,000.00 (subunits)
        'currency': 'THB',
        'paymentType': 'credit_card',
        'token': token,
        'return_uri': returnUri,
      });
    } catch (e) {
      await _setStatus('Card flow error: $e');
    }
  }

  Future<void> _payWithPromptPay() async {
    await _processPayment({
      'amount': 100000,
      'currency': 'THB',
      'paymentType': 'promptpay',
      // no return_uri needed for PromptPay
    });
  }

  Future<void> _payWithInternetBanking() async {
    await _processPayment({
      'amount': 100000,
      'currency': 'THB',
      'paymentType': 'internet_banking',
      'bank': 'bbl', // or 'bay', 'scb', etc.
      'return_uri': returnUri, // required for redirect flows
    });
  }

  Future<void> _openAuthorize() async {
    final uriStr = _authorizeUri;
    if (uriStr == null) return;

    final uri = Uri.tryParse(uriStr);
    if (uri == null) {
      await _setStatus('Invalid authorize URI');
      return;
    }

    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        await _setStatus('Failed to open browser for authorization');
      }
    } catch (e) {
      await _setStatus('Error launching URI: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkDisplay = publicKey.isEmpty
        ? '(missing OMISE_PUBLIC_KEY)'
        : publicKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Public Key',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      pkDisplay,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text('Backend: $backendUrl'),
                    Text('User ID: ${widget.userId}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _payWithCard,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Credit Card (Tokenized)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _payWithPromptPay,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('PromptPay'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _payWithInternetBanking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Internet Banking'),
            ),
            const SizedBox(height: 24),

            if (_authorizeUri != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Authorization needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _authorizeUri!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _openAuthorize,
                        child: const Text('Open bank authorization'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_qrUrl != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Scan to pay (PromptPay)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Image.network(_qrUrl!, height: 220, fit: BoxFit.contain),
                      const SizedBox(height: 8),
                      Text(
                        'Charge: ${_chargeId ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Payment Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Text(_message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
