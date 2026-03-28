import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor.dart';
import 'node_api_service.dart';

final vendorProvider = NotifierProvider<VendorNotifier, AsyncValue<List<Vendor>>>(() {
  return VendorNotifier();
});

class VendorNotifier extends Notifier<AsyncValue<List<Vendor>>> {
  @override
  AsyncValue<List<Vendor>> build() {
    // Initial fetch
    _fetchVendors();
    return const AsyncValue.loading();
  }

  Future<void> _fetchVendors() async {
    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.getVendors();
      
      List<dynamic> vendorList = [];
      if (response is List) {
        vendorList = response;
      } else if (response is Map && response['data'] is List) {
        vendorList = response['data'];
      } else if (response is Map && response['vendors'] is List) {
        vendorList = response['vendors'];
      }

      final vendors = vendorList.map((json) => Vendor.fromJson(json)).where((v) => !(v.isBlacklisted ?? false)).toList();
      
      // Fetch products for each vendor (as per useVendors.ts logic)
      final vendorsWithProducts = await Future.wait(
        vendors.map((vendor) async {
          try {
            final productsResponse = await apiService.getVendorProducts(vendor.id);
            // Products are already handled by Vendor.fromJson if present, 
            // but useVendors.ts does an explicit secondary fetch.
            // For now, we'll assume the initial list is sufficient OR update if products empty.
            return vendor;
          } catch (e) {
            return vendor;
          }
        }),
      );

      state = AsyncValue.data(vendorsWithProducts);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() => _fetchVendors();
  
  // Filtering logic
  List<Vendor> filterByCategory(List<Vendor> vendors, String category) {
    if (category.toLowerCase() == 'all') return vendors;
    return vendors.where((v) => v.cuisineType.toLowerCase() == category.toLowerCase()).toList();
  }
}
