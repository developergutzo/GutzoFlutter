import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

final vendorProvider = NotifierProvider<VendorNotifier, AsyncValue<Vendor?>>(() {
  return VendorNotifier();
});

class VendorNotifier extends Notifier<AsyncValue<Vendor?>> {
  Future<void> setVendor(Vendor vendor) async {
    state = AsyncValue.data(vendor);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('vendor_data', jsonEncode(vendor.toJson()));
    print('✅ VendorProvider: Manually set vendor: ${vendor.name}');
  }

  @override
  AsyncValue<Vendor?> build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final user = ref.watch(currentUserProvider);
    
    // Use a microtask to avoid side effects during build
    Future.microtask(() => _loadInitial(prefs, user?.phone, user?.id));
    
    return const AsyncValue.loading();
  }

  Future<void> _loadInitial(SharedPreferences prefs, String? phone, String? vendorId) async {
    print('📦 VendorProvider: Loading initial data. ID: $vendorId, Phone: $phone');
    final cached = prefs.getString('vendor_data');
    if (cached != null) {
      try {
        final vendor = Vendor.fromJson(jsonDecode(cached));
        print('✅ VendorProvider: Found cached vendor: ${vendor.name}');
        state = AsyncValue.data(vendor);
        
        // Background refresh
        if (vendorId != null && vendorId.isNotEmpty) {
           _fetchVendorBackground(id: vendorId);
        } else if (phone != null && phone.isNotEmpty) {
           _fetchVendorBackground(phone: phone);
        }
      } catch (e) {
        print('⚠️ VendorProvider: Failed to decode cache: $e');
        fetchVendor(phone: phone, id: vendorId);
      }
    } else {
      fetchVendor(phone: phone, id: vendorId);
    }
  }

  Future<void> _fetchVendorBackground({String? phone, String? id}) async {
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = id != null 
          ? await apiService.getVendorProfile(id)
          : await apiService.checkVendorStatus(phone!);

      if (response['success'] == true && response['data'] != null) {
        final vendorData = response['data']['vendor'];
        if (vendorData != null) {
          final vendor = Vendor.fromJson(vendorData);
          state = AsyncValue.data(vendor);
          final prefs = ref.read(sharedPrefsProvider);
          await prefs.setString('vendor_data', jsonEncode(vendor.toJson()));
        }
      }
    } catch (_) {}
  }

  Future<void> fetchVendor({String? phone, String? id}) async {
    final apiService = ref.read(nodeApiServiceProvider);
    final userId = id ?? ref.read(currentUserProvider)?.id;
    final userPhone = phone ?? ref.read(currentUserProvider)?.phone;
    
    print('🔍 VendorProvider: fetchVendor() called. ID: $userId, Phone: $userPhone');
    
    if ((userId == null || userId.isEmpty) && (userPhone == null || userPhone.isEmpty)) {
      print('⚠️ VendorProvider: Cannot fetch vendor, no ID or phone');
      state = const AsyncValue.data(null);
      return;
    }
    
    state = const AsyncValue.loading();
    try {
      final response = (userId != null && userId.isNotEmpty && !userId.contains('@'))
          ? await apiService.getVendorProfile(userId)
          : await apiService.checkVendorStatus(userPhone!);

      print('✅ VendorProvider: Fetch successful. Data keys: ${response['data']?.keys}');
      
      if (response['success'] == true && response['data'] != null) {
        final vendorData = response['data']['vendor'];
        if (vendorData != null) {
          final vendor = Vendor.fromJson(vendorData as Map<String, dynamic>);
          state = AsyncValue.data(vendor);
          final prefs = ref.read(sharedPrefsProvider);
          await prefs.setString('vendor_data', jsonEncode(vendor.toJson()));
          print('✅ VendorProvider: Vendor profile synchronized: ${vendor.name}');
        } else {
          print('ℹ️ VendorProvider: No vendor profile object in response (Status: ${response['data']['status']})');
          state = const AsyncValue.data(null);
        }
      } else {
        print('❌ VendorProvider: Backend returned success=false or null data');
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      print('❌ VendorProvider: Fetch failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(bool isOpen) async {
    final currentVendor = state.value;
    if (currentVendor == null) return;

    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.updateVendorStatus(currentVendor.id, isOpen);
      if (response['success'] == true) {
        final updatedVendor = currentVendor.copyWith(isOpen: isOpen);
        state = AsyncValue.data(updatedVendor);
        final prefs = ref.read(sharedPrefsProvider);
        await prefs.setString('vendor_data', jsonEncode(updatedVendor.toJson()));
      }
    } catch (e) {
      print('❌ VendorProvider: Status update failed: $e');
    }
  }

  Future<void> updateProfile(Vendor updatedVendor) async {
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.updateVendorProfile(updatedVendor.id, updatedVendor.toProfileUpdateJson());
      
      if (response['success'] == true) {
        state = AsyncValue.data(updatedVendor);
        final prefs = ref.read(sharedPrefsProvider);
        await prefs.setString('vendor_data', jsonEncode(updatedVendor.toJson()));
        print('✅ VendorProvider: Profile updated and cached');
      }
    } catch (e) {
      print('❌ VendorProvider: Profile update failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove('vendor_data');
    print('🚪 VendorProvider: Logged out and cleared cache');
  }
}
