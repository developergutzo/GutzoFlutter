import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../auth/vendor_provider.dart';
import '../../common/providers/loading_provider.dart';

final menuProvider = NotifierProvider<MenuNotifier, AsyncValue<List<Product>>>(() {
  return MenuNotifier();
});

class MenuNotifier extends Notifier<AsyncValue<List<Product>>> {
  @override
  AsyncValue<List<Product>> build() {
    final vendorAsync = ref.watch(vendorProvider);
    final vendorId = vendorAsync.value?.id;
    
    if (vendorId != null) {
      // Trigger fetch in microtask to avoid side-effects during build
      Future.microtask(() => fetchMenu(vendorId: vendorId));
      return const AsyncValue.loading();
    }
    
    // If vendor is still loading, reflect that in Menu state
    if (vendorAsync is AsyncLoading) {
      return const AsyncValue.loading();
    }

    // Default to empty if no vendor (unauthenticated state)
    return const AsyncValue.data([]);
  }

  Future<void> fetchMenu({String? vendorId}) async {
    final vId = vendorId ?? ref.read(vendorProvider).value?.id;
    
    if (vId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.getPartnerVendorMenu(vId);
      
      if (response['success'] == true) {
        final List<dynamic> productsData = response['data']['products'] ?? [];
        final products = productsData.map((p) => Product.fromJson(p)).toList();
        state = AsyncValue.data(products);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAvailability(String productId, bool isAvailable) async {
    final vId = ref.read(vendorProvider).value?.id;
    if (vId == null) return;

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.updateVendorProduct(vId, productId, {'is_available': isAvailable});
      if (response['success'] == true) {
        state = state.whenData((products) => products.map<Product>((p) {
          if (p.id == productId) {
            return p.copyWith(isAvailable: isAvailable);
          }
          return p;
        }).toList());
      }
    } catch (e) {
      print('❌ MenuNotifier: Update availability failed: $e');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> updateProduct(Product product) async {
    final vId = ref.read(vendorProvider).value?.id;
    if (vId == null) return;

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      
      final response = await apiService.updateVendorProduct(vId, product.id, product.toApiJson());
      if (response['success'] == true) {
        state = state.whenData((products) => products.map<Product>((p) {
          if (p.id == product.id) {
            return product;
          }
          return p;
        }).toList());
      }
    } catch (e) {
      print('❌ MenuNotifier: Update product failed: $e');
      rethrow;
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> deleteProduct(String productId) async {
    final vId = ref.read(vendorProvider).value?.id;
    if (vId == null) return;

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final apiService = ref.read(nodeApiServiceProvider);
      final response = await apiService.deleteVendorProduct(vId, productId);
      if (response['success'] == true) {
        state = state.whenData((products) => products.where((p) => p.id != productId).toList());
      }
    } catch (e) {
      print('❌ MenuNotifier: Delete product failed: $e');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }
}
