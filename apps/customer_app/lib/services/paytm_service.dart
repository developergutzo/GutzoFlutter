import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paytm_allinonesdk/paytm_allinonesdk.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:flutter/foundation.dart';

class PaytmService {
  final NodeApiService _apiService;

  PaytmService(this._apiService);

  Future<Map<String, dynamic>> startPayment({
    required String orderId,
    required double amount,
    bool isStaging = true,
    String? overridePhone,
  }) async {
    try {
      // 1. Initiate transaction on our backend
      final response = await _apiService.initiatePaytmTransaction(
        orderId: orderId,
        amount: amount,
        channel: 'WAP',
        overridePhone: overridePhone,
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to initiate transaction');
      }

      final paytmResponse = response['paytmResponse'];
      final body = paytmResponse['body'];
      final String txnToken = body['txnToken'];
      final String mid = body['mid'];
      final String order_number = paytmResponse['orderId'] ?? orderId;

      print('🚀 Paytm SDK Initiate: mid=$mid, orderId=$order_number, token=$txnToken');

      // 2. Start the native SDK
      final Map<dynamic, dynamic> result = await AllInOneSdk.startTransaction(
        mid,
        order_number,
        amount.toStringAsFixed(2),
        txnToken,
        "", // Use empty string instead of null as the SDK expects a String
        isStaging,
        false, // AppInvoke: false for now to rely on SDK's netbanking/wallet fallback if app not present
      ) ?? {};

      print('✅ Paytm SDK Result: $result');

      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('❌ Paytm Service Error: $e');
      rethrow;
    }
  }
}

final paytmServiceProvider = Provider<PaytmService>((ref) {
  final apiService = ref.watch(nodeApiServiceProvider);
  return PaytmService(apiService);
});
