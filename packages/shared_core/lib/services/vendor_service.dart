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
    // 📍 Re-fetch vendors whenever the location or address changes
    final locationState = ref.watch(locationProvider);
    final location = locationState.location;
    final address = location?.displayString;
    
    _fetchVendors(location?.latitude, location?.longitude, address);
    return const AsyncValue.loading();
  }

  Future<void> _fetchVendors(double? lat, double? lng, String? address) async {
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
                'address': vendor.location.isNotEmpty ? vendor.location : vendor.name,
                'latitude': vendor.latitude,
                'longitude': vendor.longitude,
              };
              final drop = {
                'address': address ?? '', // 📍 Use real address if available
                'latitude': lat,
                'longitude': lng,
              };

              final res = await apiService.getDeliveryServiceability(pickup, drop);

              // 📍 Mirror webapp logic exactly:
              // const isServiceable = res.data && (res.data.is_serviceable !== undefined ? res.data.is_serviceable : (res.data.value?.is_serviceable ?? true));
              
              final data = res is Map ? (res['data'] ?? res) : null;
              bool isServiceable = true; // Default to true if missing (matching webapp fallback)

              if (data != null && data is Map) {
                if (data['is_serviceable'] != null) {
                  // Handle both bool and int (0/1) types
                  final val = data['is_serviceable'];
                  isServiceable = val is bool ? val : (val == 1 || val == '1' || val == 'true');
                } else if (data['value'] != null && data['value'] is Map && data['value']['is_serviceable'] != null) {
                  final val = data['value']['is_serviceable'];
                  isServiceable = val is bool ? val : (val == 1 || val == '1' || val == 'true');
                }
              }

              return vendor.copyWith(isServiceable: isServiceable);
            } catch (e) {
              debugPrint('Serviceability check failed for ${vendor.name}: $e');
              // On API error (network, missing coords, etc.) — return vendor as-is
              // so it shows normally, matching the webapp behavior
              return vendor;
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
    final locationState = ref.read(locationProvider);
    final location = locationState.location;
    final address = location?.displayString;
    return _fetchVendors(location?.latitude, location?.longitude, address);
  }
  
  // Filtering logic
  List<model.Vendor> filterByCategory(List<model.Vendor> vendors, String category) {
    if (category.toLowerCase() == 'all') return vendors;
    return vendors.where((v) => v.cuisineType.toLowerCase() == category.toLowerCase()).toList();
  }
}
