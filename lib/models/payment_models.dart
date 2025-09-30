// Payment Models
class PaymentRequest {
  final int amount; // satang unit: 100 satang = 1 THB
  final String currency; // "THB"
  final String paymentType; // "credit_card" | "promptpay" | "internet_banking"
  final String description;
  final int userId;
  final String? token; // for card charges (preferred)
  final Map<String, dynamic>? card; // server-side tokenization (TESTING ONLY)
  final String? bank; // e.g. "bbl", "bay", "scb"
  final String? returnUri; // required for some redirects (3DS/internet banking)
  final Map<String, dynamic>?
  metadata; // free-form, attached to the Omise charge

  PaymentRequest({
    required this.amount,
    required this.currency,
    required this.paymentType,
    required this.description,
    required this.userId,
    this.token,
    this.card,
    this.bank,
    this.returnUri,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'paymentType': paymentType,
      'description': description,
      'user_id': userId,
      if (token != null) 'token': token,
      if (card != null) 'card': card,
      if (bank != null) 'bank': bank,
      if (returnUri != null) 'return_uri': returnUri,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class Transaction {
  final int id;
  final String chargeId;
  final int userId;
  final int amountSatang;
  final String currency;
  final String status;
  final String channel;
  final String? failureCode;
  final String? failureMessage;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.chargeId,
    required this.userId,
    required this.amountSatang,
    required this.currency,
    required this.status,
    required this.channel,
    this.failureCode,
    this.failureMessage,
    this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      chargeId: json['charge_id'],
      userId: json['user_id'],
      amountSatang: json['amount_satang'],
      currency: json['currency'],
      status: json['status'],
      channel: json['channel'],
      failureCode: json['failure_code'],
      failureMessage: json['failure_message'],
      meta: json['meta'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'charge_id': chargeId,
      'user_id': userId,
      'amount_satang': amountSatang,
      'currency': currency,
      'status': status,
      'channel': channel,
      'failure_code': failureCode,
      'failure_message': failureMessage,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TransactionListResponse {
  final List<Transaction> transactions;
  final TransactionPagination pagination;

  TransactionListResponse({
    required this.transactions,
    required this.pagination,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    return TransactionListResponse(
      transactions: (json['transactions'] as List)
          .map((e) => Transaction.fromJson(e))
          .toList(),
      pagination: TransactionPagination.fromJson(json['pagination']),
    );
  }
}

class TransactionPagination {
  final int limit;
  final int offset;
  final int total;

  TransactionPagination({
    required this.limit,
    required this.offset,
    required this.total,
  });

  factory TransactionPagination.fromJson(Map<String, dynamic> json) {
    return TransactionPagination(
      limit: json['limit'],
      offset: json['offset'],
      total: json['total'],
    );
  }
}
