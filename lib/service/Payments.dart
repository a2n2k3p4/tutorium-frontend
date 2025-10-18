import 'package:tutorium_frontend/service/api_client.dart';

class PaymentRequest {
  final int amount; // satang (100 == 1 THB)
  final String currency;
  final String paymentType;
  final String description;
  final int userId;
  final Map<String, dynamic>? metadata;
  final String? token;
  final Map<String, dynamic>? card;
  final String? bank;
  final String? returnUri;

  const PaymentRequest({
    required this.amount,
    required this.currency,
    required this.paymentType,
    required this.description,
    required this.userId,
    this.metadata,
    this.token,
    this.card,
    this.bank,
    this.returnUri,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'paymentType': paymentType,
      'description': description,
      'user_id': userId,
      if (metadata != null) 'metadata': metadata,
      if (token != null) 'token': token,
      if (card != null) 'card': card,
      if (bank != null) 'bank': bank,
      if (returnUri != null) 'return_uri': returnUri,
    };
    return json;
  }
}

class PaymentChargeResult {
  final String chargeId;
  final bool paid;
  final String status;
  final String? qrCodeUrl;
  final Map<String, dynamic> raw;

  PaymentChargeResult({
    required this.chargeId,
    required this.paid,
    required this.status,
    this.qrCodeUrl,
    required this.raw,
  });

  factory PaymentChargeResult.fromJson(Map<String, dynamic> json) {
    return PaymentChargeResult(
      chargeId: json['charge_id'] ?? json['id'] ?? '',
      paid: json['paid'] ?? false,
      status: json['status'] ?? 'pending',
      qrCodeUrl: json['qr_code_url'],
      raw: json,
    );
  }
}

class PaymentStatusResult {
  final String chargeId;
  final bool paid;
  final String status;
  final Map<String, dynamic> raw;

  PaymentStatusResult({
    required this.chargeId,
    required this.paid,
    required this.status,
    required this.raw,
  });

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      chargeId: json['charge_id'] ?? json['id'] ?? '',
      paid: json['paid'] ?? false,
      status: json['status'] ?? 'pending',
      raw: json,
    );
  }
}

class PaymentsService {
  static final ApiClient _client = ApiClient();

  /// POST /payments/charge
  static Future<PaymentChargeResult> createCharge(
    PaymentRequest request,
  ) async {
    final response = await _client.postJsonMap(
      '/payments/charge',
      body: request.toJson(),
    );
    return PaymentChargeResult.fromJson(response);
  }

  /// POST /webhooks/omise
  static Future<PaymentStatusResult> checkCharge(String chargeId) async {
    final response = await _client.postJsonMap(
      '/webhooks/omise',
      body: {'id': chargeId, 'object': 'charge'},
    );
    return PaymentStatusResult.fromJson(response);
  }
}
