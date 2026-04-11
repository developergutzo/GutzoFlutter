import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../auth/vendor_provider.dart';

final dashboardStatsProvider = NotifierProvider<DashboardStatsNotifier, AsyncValue<Map<String, dynamic>>>(() {
  return DashboardStatsNotifier();
});

class DashboardStatsNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  @override
  AsyncValue<Map<String, dynamic>> build() {
    final vendorId = ref.watch(vendorProvider).value?.id;
    if (vendorId != null) {
      Future.microtask(() => fetchStats(vendorId));
      return const AsyncValue.loading();
    }
    return const AsyncValue.data({});
  }

  Future<void> fetchStats(String vendorId) async {
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.getVendorDashboardStats(vendorId);
      if (response['success'] == true) {
        state = AsyncValue.data(response['data']['stats'] as Map<String, dynamic>);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
