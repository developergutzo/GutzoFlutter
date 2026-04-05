import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/address.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';

class SavedAddressesNotifier extends AsyncNotifier<List<UserAddress>> {
  @override
  Future<List<UserAddress>> build() async {
    return _fetch();
  }

  Future<List<UserAddress>> _fetch() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];

    try {
      final response = await ref.read(nodeApiServiceProvider).getUserAddresses(user.phone);
      final List<dynamic> data = response['data'] ?? response ?? [];
      return data
          .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Re-fetch from backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

final savedAddressesProvider =
    AsyncNotifierProvider<SavedAddressesNotifier, List<UserAddress>>(
  SavedAddressesNotifier.new,
);
