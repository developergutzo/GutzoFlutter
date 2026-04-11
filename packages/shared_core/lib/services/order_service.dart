import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'node_api_service.dart';

import 'auth_service.dart';

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final api = ref.read(nodeApiServiceProvider);
  final user = ref.watch(currentUserProvider);
  
  if (user == null || user.phone.isEmpty) {
    throw Exception("Authentication required. Provide x-user-phone header.");
  }

  final response = await api.getUserOrders(overridePhone: user.phone);
  
  List<dynamic> data = [];
  if (response is List) {
    data = response;
  } else if (response is Map && response['data'] is List) {
    data = response['data'];
  }
  
  return data.map((json) => Order.fromJson(json)).toList();
});

// Real-time tracking stream provider
final activeOrderTrackingProvider = StreamProvider.family<OrderTrackingData, String>((ref, orderId) async* {
  final api = ref.read(nodeApiServiceProvider);
  final supabase = Supabase.instance.client;

  final user = ref.watch(currentUserProvider);
  final userPhone = user?.phone;

  // Initial fetch
  Future<OrderTrackingData> fetch() async {
    final response = await api.getOrderTracking(orderId, overridePhone: userPhone);
    if (response is Map && response['data'] != null) {
      return OrderTrackingData.fromJson(Map<String, dynamic>.from(response['data']));
    } else if (response is Map) {
      return OrderTrackingData.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception("No data");
  }

  // Yield initial data
  yield await fetch();

  // Listen for Supabase updates
  final controller = StreamController<OrderTrackingData>();
  final channel = supabase
      .channel('order_status_$orderId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: orderId,
        ),
        callback: (payload) async {
          try {
            final data = await fetch();
            controller.add(data);
          } catch (e) {
            // ignore
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  yield* controller.stream;
});
