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

/// 🎯 Tracks the order ID currently being followed by the user (shown in the Home Screen strip)
final currentTrackingOrderIdProvider = StateProvider<String?>((ref) => null);

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

/// 🎯 Tracks all orders that are NOT in a final state (delivered, cancelled)
final liveActiveOrdersProvider = StreamProvider<List<Order>>((ref) async* {
  final supabase = Supabase.instance.client;
  final user = ref.watch(currentUserProvider);
  if (user == null) {
     yield [];
     return;
  }

  // Poll for initially active orders
  Future<List<Order>> fetchActive() async {
    final response = await ref.read(nodeApiServiceProvider).getUserOrders(overridePhone: user.phone);
    List<dynamic> data = (response is List) ? response : (response is Map ? response['data'] ?? [] : []);
    return data
        .map((json) => Order.fromJson(json))
        .where((o) => !['delivered', 'cancelled', 'completed'].contains(o.status.toLowerCase()))
        .toList();
  }

  yield await fetchActive();

  // Listen for ANY order changes for this user
  final controller = StreamController<List<Order>>();
  final channel = supabase
      .channel('live_orders_${user.phone}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_phone',
          value: user.phone,
        ),
        callback: (payload) async {
          final active = await fetchActive();
          controller.add(active);
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  yield* controller.stream;
});
