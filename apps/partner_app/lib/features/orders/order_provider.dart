import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../auth/vendor_provider.dart';
import '../../common/providers/loading_provider.dart';

final orderListProvider = NotifierProvider<OrderListNotifier, AsyncValue<List<Order>>>(() {
  return OrderListNotifier();
});

class OrderListNotifier extends Notifier<AsyncValue<List<Order>>> {
  @override
  AsyncValue<List<Order>> build() {
    final vendorAsync = ref.watch(vendorProvider);
    
    print('📦 OrderListNotifier: build() triggered. Vendor state: ${vendorAsync.runtimeType}');

    final vendorId = vendorAsync.value?.id;

    if (vendorId != null) {
      print('🚀 OrderListNotifier: Vendor ID found ($vendorId), triggering initial fetch');
      Future.microtask(() => fetchOrders(vendorId: vendorId));
      return const AsyncValue.loading();
    }
    
    if (vendorAsync is AsyncLoading) {
       print('⏳ OrderListNotifier: Waiting for vendor data to load...');
       return const AsyncValue.loading();
    }

    print('ℹ️ OrderListNotifier: No vendor ID found and vendor provider is not loading. Returning empty list.');
    return const AsyncValue.data([]);
  }

  Future<void> _fetchInitial(String vendorId) async {
    fetchOrders(vendorId: vendorId);
  }

  Future<void> fetchOrders({String? status, String? vendorId}) async {
    final vId = vendorId ?? ref.read(vendorProvider).value?.id;
    
    print('🔍 OrderListNotifier: fetchOrders() called for vendor: $vId');
    
    if (vId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.getPartnerVendorOrders(vId, status: status);
      
      print('✅ OrderListNotifier: API response received for vendor: $vId');
      
      if (response['success'] == true) {
        final List<dynamic> ordersData = response['data']['orders'] ?? [];
        final orders = ordersData.map((o) => Order.fromJson(o)).toList();
        print('📦 OrderListNotifier: Successfully fetched ${orders.length} orders');
        state = AsyncValue.data(orders);
      } else {
        print('⚠️ OrderListNotifier: Backend returned success=false');
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      print('❌ OrderListNotifier: Fetch failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final vId = ref.read(vendorProvider).value?.id;
    if (vId == null) return;

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.updateVendorOrderStatus(vId, orderId, newStatus);
      if (response['success'] == true) {
        // Fetch fresh state but skip AsyncLoading to avoid skeleton flickering behind the global overlay
        await _fetchOrdersSilently(vId);
      }
    } catch (e) {
      print('❌ OrderListNotifier: Update order status failed: $e');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _fetchOrdersSilently(String vId) async {
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.getPartnerVendorOrders(vId);
      if (response['success'] == true) {
        final List<dynamic> ordersData = response['data']['orders'] ?? [];
        final orders = ordersData.map((o) => Order.fromJson(o)).toList();
        state = AsyncValue.data(orders);
      }
    } catch (_) {}
  }
}
