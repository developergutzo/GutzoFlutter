import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart' as model;
import 'package:shared_core/models/product.dart' as model;
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/services/location_service.dart';

final vendorProvider = NotifierProvider<VendorNotifier, AsyncValue<List<model.Vendor>>>(() {
  return VendorNotifier();
});

class VendorNotifier extends Notifier<AsyncValue<List<model.Vendor>>> {
  @override
  AsyncValue<List<model.Vendor>> build() {
    // 📍 Re-fetch vendors whenever the location changes
    final location = ref.watch(locationProvider).location;
    _fetchVendors(location?.latitude, location?.longitude);
    return const AsyncValue.loading();
  }

  Future<void> _fetchVendors(double? lat, double? lng) async {
    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      // Fetch all vendors (no lat/lng filtering at backend — check per vendor client-side like webapp)
      final response = await apiService.getVendors();
      
      List<dynamic> vendorList = [];
      if (response is List) {
        vendorList = response;
      } else if (response is Map && response['data'] is List) {
        vendorList = response['data'];
      } else if (response is Map && response['vendors'] is List) {
        vendorList = response['vendors'];
      }

      // Filter blacklisted
      final vendors = vendorList
          .map((json) => model.Vendor.fromJson(json))
          .where((v) => !(v.isBlacklisted ?? false))
          .toList();

      List<model.Vendor> validVendors = vendors;

      // 📍 Per-vendor serviceability check (mirroring webapp useVendors.ts)
      if (lat != null && lng != null) {
        final checkedVendors = await Future.wait(
          vendors.map((vendor) async {
            // Skip vendors without coordinates (same as webapp)
            if (vendor.latitude == null || vendor.longitude == null) {
              return vendor; // no serviceability info, show as-is
            }
            try {
              final pickup = {
                'address': vendor.location,
                'latitude': vendor.latitude,
                'longitude': vendor.longitude,
              };
              final drop = {
                'address': '',
                'latitude': lat,
                'longitude': lng,
              };

              final res = await apiService.getDeliveryServiceability(pickup, drop);

              // Mirror webapp logic: check is_serviceable explicitly or fallback to value.is_serviceable
              final data = res is Map ? (res['data'] ?? res) : null;
              final bool isServiceable;
              if (data != null) {
                if (data['is_serviceable'] != null) {
                  isServiceable = data['is_serviceable'] as bool;
                } else if (data['value'] != null && data['value']['is_serviceable'] != null) {
                  isServiceable = data['value']['is_serviceable'] as bool;
                } else {
                  isServiceable = true; // fallback: assume serviceable
                }
              } else {
                isServiceable = true;
              }

              return vendor.copyWith(isServiceable: isServiceable);
            } catch (e) {
              debugPrint('Serviceability check failed for ${vendor.name}: $e');
              // On error, hide the vendor (same policy as webapp comment)
              return vendor.copyWith(isServiceable: false);
            }
          }),
        );
        validVendors = checkedVendors;
      }

      // Fetch products for each vendor and merge
      final vendorsWithProducts = await Future.wait(
        validVendors.map((vendor) async {
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

            final List<model.Product> products = productList
                .map((json) => model.Product.fromJson(json as Map<String, dynamic>))
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

  Future<void> refresh() {
    final location = ref.read(locationProvider).location;
    return _fetchVendors(location?.latitude, location?.longitude);
  }
  
  // Filtering logic
  List<model.Vendor> filterByCategory(List<model.Vendor> vendors, String category) {
    if (category.toLowerCase() == 'all') return vendors;
    return vendors.where((v) => v.cuisineType.toLowerCase() == category.toLowerCase()).toList();
  }
}
