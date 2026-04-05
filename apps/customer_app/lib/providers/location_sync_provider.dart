import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/location_service.dart';
import 'address_provider.dart';

/// Notifier that manages the synchronization of database addresses to current location
class LocationSyncNotifier extends Notifier<void> {
  @override
  void build() {
    // Watch saved addresses and react to changes
    final addressesAsync = ref.watch(savedAddressesProvider);

    addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          // No addresses in DB, so trigger a fresh GPS search
          Future.microtask(() {
            ref.read(locationProvider.notifier).refreshLocation();
          });
          return;
        }

        // Find the current default address
        final defaultAddress = addresses.firstWhere(
          (element) => element.isDefault == true,
          orElse: () => addresses.first, 
        );

        final locationData = LocationData(
          city: defaultAddress.city,
          state: defaultAddress.state,
          country: defaultAddress.country,
          formattedAddress: defaultAddress.fullAddress,
          latitude: defaultAddress.latitude ?? 0.0,
          longitude: defaultAddress.longitude ?? 0.0,
          timestamp: DateTime.now(),
        );

        // Update the global location provider atomically
        Future.microtask(() {
           debugPrint('📍 Sync: Finalizing location from DB');
           ref.read(locationProvider.notifier).overrideLocation(locationData);
        });
      },
      loading: () => {},
      error: (err, stack) {
        // If DB fails, fallback to GPS
        Future.microtask(() {
          ref.read(locationProvider.notifier).refreshLocation();
        });
      },
    );
  }
}

final locationSyncProvider = NotifierProvider<LocationSyncNotifier, void>(() {
  return LocationSyncNotifier();
});
