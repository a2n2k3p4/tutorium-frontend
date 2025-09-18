import '../models/payment_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class PaymentService extends BaseApiService {
  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await get(ApiConfig.health, includeAuth: false);
    return handleResponse(response);
  }

  // Create a payment charge
  Future<Map<String, dynamic>> createCharge(
    PaymentRequest paymentRequest,
  ) async {
    final response = await post(
      '${ApiConfig.payments}/charge',
      paymentRequest.toJson(),
    );
    return handleResponse(response);
  }

  // List transactions with optional filters
  Future<TransactionListResponse> getTransactions({
    String? userId,
    String? status,
    String? channel,
    int? limit,
    int? offset,
  }) async {
    String endpoint = '${ApiConfig.payments}/transactions';
    List<String> queryParams = [];

    if (userId != null) queryParams.add('user_id=$userId');
    if (status != null) queryParams.add('status=$status');
    if (channel != null) queryParams.add('channel=$channel');
    if (limit != null) queryParams.add('limit=$limit');
    if (offset != null) queryParams.add('offset=$offset');

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    final response = await get(endpoint, includeAuth: false);
    final data = handleResponse(response);
    return TransactionListResponse.fromJson(data);
  }

  // Get transaction by ID
  Future<Transaction> getTransactionById(String id) async {
    final response = await get(
      '${ApiConfig.payments}/transactions/$id',
      includeAuth: false,
    );
    final data = handleResponse(response);
    return Transaction.fromJson(data);
  }

  // Refund a transaction
  Future<Map<String, dynamic>> refundTransaction(
    String id, {
    int? amount,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) {
      body['amount'] = amount;
    }

    final response = await post(
      '${ApiConfig.payments}/transactions/$id/refund',
      body,
    );
    return handleResponse(response);
  }

  // Omise webhook (for internal use)
  Future<String> handleOmiseWebhook(Map<String, dynamic> payload) async {
    final response = await post(
      '${ApiConfig.webhooks}/omise',
      payload,
      includeAuth: false,
    );
    return response.body;
  }
}
