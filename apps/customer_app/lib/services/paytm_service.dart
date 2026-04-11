import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:flutter/foundation.dart';

class PaytmService {
  final NodeApiService _apiService;
  static const _channel = MethodChannel('in.gutzo.customer_app/paytm');

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

      final data = response['data'] ?? {};
      final paytmResponse = data['paytmResponse'];
      
      if (paytmResponse == null) {
        throw Exception('Invalid payment response from server');
      }

      final body = paytmResponse['body'] ?? {};
      final String txnToken = body['txnToken'] ?? "";
      final String mid = data['mid'] ?? "";
      final String order_number = data['orderId'] ?? paytmResponse['orderId'] ?? orderId;

      final args = {
        'mid': mid,
        'orderId': order_number,
        'amount': amount.toStringAsFixed(2),
        'txnToken': txnToken,
        'callbackUrl': "", // Native handle default
        'isStaging': isStaging,
        'restrictAppInvoke': false,
      };

      print('📡 [Paytm Bridge] Sending to Native: $args');

      // 2. Start the native SDK via MethodChannel
      final dynamic result = await _channel.invokeMethod('startTransaction', args);

      print('✅ [Paytm Bridge] Native Result: $result');

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e, stack) {
      print('❌ [Paytm Bridge] Error: $e');
      print('📄 [Paytm Bridge] Stacktrace: $stack');
      rethrow;
    }
  }
}

final paytmServiceProvider = Provider<PaytmService>((ref) {
  final apiService = ref.watch(nodeApiServiceProvider);
  return PaytmService(apiService);
});
