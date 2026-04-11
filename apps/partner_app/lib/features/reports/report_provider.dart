import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../auth/vendor_provider.dart';

final gstReportProvider = NotifierProvider<GSTReportNotifier, AsyncValue<Map<String, dynamic>>>(() {
  return GSTReportNotifier();
});

class GSTReportNotifier extends Notifier<AsyncValue<Map<String, dynamic>>> {
  @override
  AsyncValue<Map<String, dynamic>> build() {
    return const AsyncValue.loading();
  }

  Future<void> fetchReport({String? from, String? to}) async {
    final vendorId = ref.read(vendorProvider).value?.id;
    if (vendorId == null) {
      state = const AsyncValue.error('Vendor ID not found', StackTrace.empty);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      
      // Default dates if not provided (this month)
      final now = DateTime.now();
      final defaultFrom = from ?? DateTime(now.year, now.month, 1).toIso8601String();
      final defaultTo = to ?? now.toIso8601String();

      final response = await apiService.getVendorGSTReport(vendorId, defaultFrom, defaultTo);
      
      if (response['success'] == true) {
        state = AsyncValue.data(response['data'] as Map<String, dynamic>);
      } else {
        state = AsyncValue.error(response['message'] ?? 'Failed to fetch report', StackTrace.empty);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
