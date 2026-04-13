import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/vendor.dart';
import 'auth_service.dart';
import 'node_api_service.dart';

class CartItem {
  final Product product;
  final Vendor vendor;
  final int quantity;
  final bool isHabit; // NEW: Item-level habit flag
  final String? id; // Backend cart item ID

  CartItem({
    required this.product,
    required this.vendor,
    this.quantity = 1,
    this.isHabit = false,
    this.id,
  });

  CartItem copyWith({int? quantity, bool? isHabit, String? id}) {
    return CartItem(
      product: product,
      vendor: vendor,
      quantity: quantity ?? this.quantity,
      isHabit: isHabit ?? this.isHabit,
      id: id ?? this.id,
    );
  }

  double get totalPrice => product.price * quantity;
}

class CartState {
  final List<CartItem> items;
  final String? vendorId; // Current cart's vendor
  final bool isLoading;

  CartState({this.items = const [], this.vendorId, this.isLoading = false});

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get originalSubtotal => items.fold(0, (sum, item) => sum + (item.product.originalPrice ?? item.product.price) * item.quantity);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({List<CartItem>? items, String? vendorId, bool? isLoading}) {
    return CartState(
      items: items ?? this.items,
      vendorId: vendorId ?? this.vendorId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

class CartNotifier extends Notifier<CartState> {
  static const _key = 'gutzo_cart';
  bool _initialized = false;

  @override
  CartState build() {
    // Watch user to trigger re-sync only when auth state actually changes
    final user = ref.watch(currentUserProvider);
    
    if (!_initialized) {
      _initialized = true;
      _initCart(user?.phone);
    }

    return CartState(isLoading: true);
  }

  Future<void> _initCart(String? phone) async {
    if (phone != null) {
      await _migrateAndLoadUserCart(phone);
    } else {
      await _loadLocalCart();
    }
  }

  Future<void> _loadLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> data = json.decode(jsonString);
        final List<dynamic> itemsJson = data['items'] ?? [];
        final items = itemsJson.map((item) => CartItem(
          product: Product.fromJson(item['product']),
          vendor: Vendor.fromJson(item['vendor']),
          quantity: item['quantity'],
          isHabit: item['isHabit'] ?? false,
        )).toList();
        state = CartState(items: items, vendorId: data['vendorId'], isLoading: false);
      } catch (e) {
        prefs.remove(_key);
        state = CartState(isLoading: false);
      }
    } else {
      state = CartState(isLoading: false);
    }
  }

  Future<void> _migrateAndLoadUserCart(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    final api = ref.read(nodeApiServiceProvider);

    try {
      // 1. Fetch current backend cart
      final backendResponse = await api.getUserCart(phone);
      final backendItems = _parseBackendItems(backendResponse);

      if (jsonString != null) {
        // 2. We have a guest cart, need to merge and migrate
        final Map<String, dynamic> localData = json.decode(jsonString);
        final List<dynamic> localItemsJson = localData['items'] ?? [];
        final localItems = localItemsJson.map((item) => CartItem(
          product: Product.fromJson(item['product']),
          vendor: Vendor.fromJson(item['vendor']),
          quantity: item['quantity'],
          isHabit: item['isHabit'] ?? false,
        )).toList();

        // Simple merge logic: Local takes precedence for quantity if already in backend
        // This matches the webapp's behavior of merging guest items into account
        final mergedItems = _mergeCarts(backendItems, localItems);

        // 3. Sync merged cart to backend
        await api.saveUserCart(phone, _transformToApiFormat(mergedItems));
        
        // 4. Clear local guest cart
        await prefs.remove(_key);
        
        // 5. Final load to get real backend IDs
        final finalResponse = await api.getUserCart(phone);
        state = CartState(
          items: _parseBackendItems(finalResponse),
          vendorId: mergedItems.isNotEmpty ? mergedItems.first.vendor.id : null,
          isLoading: false,
        );
      } else {
        // No guest cart, just use backend
        state = CartState(
          items: backendItems,
          vendorId: backendItems.isNotEmpty ? backendItems.first.vendor.id : null,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('CartService: Error migrating/loading cart: $e');
      // Fallback to local if backend fails
      await _loadLocalCart();
    }
  }

  List<CartItem> _parseBackendItems(dynamic response) {
    try {
      List<dynamic> itemsData = [];
      if (response is Map && response['data'] != null) {
        itemsData = response['data']['items'] ?? [];
      } else if (response is Map && response['items'] != null) {
        itemsData = response['items'];
      }
      
      return itemsData.map((item) {
        final productJson = item['product'] ?? item;
        final vendorJson = item['vendor'] ?? {};
        return CartItem(
          id: item['id']?.toString(),
          product: Product.fromJson(productJson),
          vendor: Vendor.fromJson(vendorJson),
          quantity: item['quantity'] ?? 1,
          isHabit: item['is_habit'] ?? item['metadata']?['is_habit'] ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('CartService: Parsing error: $e');
      return [];
    }
  }

  List<CartItem> _mergeCarts(List<CartItem> backend, List<CartItem> local) {
    // Unique key: productId + isHabit
    final Map<String, CartItem> merged = {for (var item in backend) "${item.product.id}_${item.isHabit}": item};
    for (var item in local) {
      final key = "${item.product.id}_${item.isHabit}";
      if (merged.containsKey(key)) {
        final existing = merged[key]!;
        merged[key] = existing.copyWith(quantity: existing.quantity + item.quantity);
      } else {
        merged[key] = item;
      }
    }
    return merged.values.toList();
  }

  List<Map<String, dynamic>> _transformToApiFormat(List<CartItem> items) {
    return items.map((item) => {
      'product_id': item.product.id,
      'vendor_id': item.vendor.id,
      'quantity': item.quantity,
      'is_habit': item.isHabit,
    }).toList();
  }

  Future<void> _saveCart() async {
    final user = ref.read(currentUserProvider);
    final prefs = await SharedPreferences.getInstance();

    // Local save for persistence
    final data = {
      'vendorId': state.vendorId,
      'items': state.items.map((item) => {
        'product': item.product.toJson(),
        'vendor': item.vendor.toJson(),
        'quantity': item.quantity,
        'isHabit': item.isHabit,
      }).toList(),
    };
    await prefs.setString(_key, json.encode(data));

    // Backend sync if authenticated
    if (user != null) {
      try {
        final api = ref.read(nodeApiServiceProvider);
        await api.saveUserCart(user.phone, _transformToApiFormat(state.items));
      } catch (e) {
        debugPrint('CartService: Backend sync failed: $e');
      }
    }
  }

  String? get activeVendorName => state.items.isNotEmpty ? state.items.first.vendor.name : null;

  void addItem(Product product, Vendor vendor, int quantity, {bool forceClear = false, bool isHabit = false}) {
    // Cross-vendor check
    if (state.vendorId != null && state.vendorId != vendor.id && state.items.isNotEmpty) {
      if (forceClear) {
        state = state.copyWith(
          items: [CartItem(product: product, vendor: vendor, quantity: quantity, isHabit: isHabit)],
          vendorId: vendor.id,
        );
        _saveCart();
      }
      return;
    }

    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id && item.isHabit == isHabit);
    
    if (existingIndex != -1) {
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + quantity,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(product: product, vendor: vendor, quantity: quantity, isHabit: isHabit)],
        vendorId: vendor.id,
      );
    }
    _saveCart();
  }

  void updateQuantity(String productId, int quantity, {bool isHabit = false}) {
    if (quantity <= 0) {
      removeItem(productId, isHabit: isHabit);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId && item.isHabit == isHabit) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
    _saveCart();
  }

  void removeItem(String productId, {bool isHabit = false}) {
    final updatedItems = state.items.where((item) => !(item.product.id == productId && item.isHabit == isHabit)).toList();
    state = state.copyWith(
      items: updatedItems,
      vendorId: updatedItems.isEmpty ? null : state.vendorId,
    );
    _saveCart();
  }

  void clear() {
    state = CartState();
    _saveCart();
  }
}
