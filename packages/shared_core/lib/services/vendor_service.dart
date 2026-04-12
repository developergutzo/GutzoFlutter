import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart' as model;
import 'package:shared_core/models/product.dart' as model;
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/services/distance_service.dart';

final vendorProvider = NotifierProvider<VendorNotifier, AsyncValue<List<model.Vendor>>>(() {
  return VendorNotifier();
});

class VendorNotifier extends Notifier<AsyncValue<List<model.Vendor>>> {
  int _generation = 0;

  @override
  AsyncValue<List<model.Vendor>> build() {
    // 📍 Re-fetch vendors whenever the location or address changes
    final locationState = ref.watch(locationProvider);
    final location = locationState.location;
    final address = location?.displayString;
    
    // Increment generation to ignore stale async results from previous builds
    final currentGen = ++_generation;
    
    // Clear state or set to loading immediately
    Future.microtask(() => _fetchVendors(location?.latitude, location?.longitude, address, currentGen));
    
    return const AsyncValue.loading();
  }

  Future<void> _fetchVendors(double? lat, double? lng, String? address, int gen) async {
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      // Fetch all vendors
      final response = await apiService.getVendors();
      
      // Check if this generation is still valid
      if (gen != _generation) {
        debugPrint('📍 VendorNotifier: Ignoring stale fetch (gen $gen, current $_generation)');
        return;
      }

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

      // 📍 Per-vendor serviceability check
      if (lat != null && lng != null) {
        final checkedVendors = await Future.wait(
          vendors.map((vendor) async {
            if (vendor.latitude == null || vendor.longitude == null) {
              return vendor;
            }
            try {
              final pickup = {
                'address': vendor.location.isNotEmpty ? vendor.location : vendor.name,
                'latitude': vendor.latitude,
                'longitude': vendor.longitude,
              };
              final drop = {
                'address': address ?? '',
                'latitude': lat,
                'longitude': lng,
              };

              final res = await apiService.getDeliveryServiceability(pickup, drop);
              
              final data = res is Map ? (res['data'] ?? res) : null;
              bool isServiceable = true; 
              String dynamicDeliveryTime = vendor.deliveryTime;

              if (data != null && data is Map) {
                if (data['is_serviceable'] != null) {
                  final val = data['is_serviceable'];
                  isServiceable = val is bool ? val : (val == 1 || val == '1' || val == 'true');
                } else if (data['value'] != null && data['value'] is Map && data['value']['is_serviceable'] != null) {
                  final val = data['value']['is_serviceable'];
                  isServiceable = val is bool ? val : (val == 1 || val == '1' || val == 'true');
                }

                if (isServiceable) {
                  final pickupEtaStr = data['pickup_eta'] ?? (data['value'] != null ? data['value']['pickup_eta'] : null);
                  if (pickupEtaStr != null) {
                    final travelTimeStr = await DistanceService.getTravelTime(
                      originLat: vendor.latitude!,
                      originLng: vendor.longitude!,
                      destLat: lat,
                      destLng: lng,
                    );

                    if (travelTimeStr != null) {
                      final pickupMins = DistanceService.parseDurationToMinutes(pickupEtaStr.toString());
                      final travelMins = DistanceService.parseDurationToMinutes(travelTimeStr);
                      if (pickupMins > 0 && travelMins > 0) {
                        final total = pickupMins + travelMins;
                        dynamicDeliveryTime = '$total-${total + 5} mins';
                      }
                    }
                  }
                }
              }

              return vendor.copyWith(
                isServiceable: isServiceable,
                deliveryTime: dynamicDeliveryTime,
              );
            } catch (e) {
              return vendor;
            }
          }),
        );
        validVendors = checkedVendors;
      }

      // Check generation again after heavy parallel work
      if (gen != _generation) return;

      // Fetch products for each vendor
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

      // Final generation check
      if (gen != _generation) return;

      state = AsyncValue.data(vendorsWithProducts);
    } catch (e, stack) {
      if (gen == _generation) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() async {
    final locationState = ref.read(locationProvider);
    final location = locationState.location;
    final address = location?.displayString;
    final currentGen = ++_generation;
    return _fetchVendors(location?.latitude, location?.longitude, address, currentGen);
  }
  
  // Filtering logic
  List<model.Vendor> filterByCategory(List<model.Vendor> vendors, String category) {
    if (category.toLowerCase() == 'all') return vendors;
    return vendors.where((v) => v.cuisineType.toLowerCase() == category.toLowerCase()).toList();
  }
}
