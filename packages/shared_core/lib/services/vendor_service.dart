import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/services/node_api_service.dart';

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
      
      // Fetch products for each vendor and merge them
      final vendorsWithProducts = await Future.wait(
        vendors.map((vendor) async {
          try {
            final productsResponse = await apiService.getVendorProducts(vendor.id);
            List<dynamic> productList = [];
            
            if (productsResponse is List) {
              productList = productsResponse;
            } else if (productsResponse is Map) {
              if (productsResponse['data'] is List) {
                productList = productsResponse['data'];
              } else if (productsResponse['products'] is List) {
                productList = productsResponse['products'];
              } else if (productsResponse['data'] is Map && productsResponse['data']['products'] is List) {
                productList = productsResponse['data']['products'];
              }
            }

            final List<Product> products = productList
                .map((json) => Product.fromJson(json as Map<String, dynamic>))
                .toList();
                
            return vendor.copyWith(products: products);
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
