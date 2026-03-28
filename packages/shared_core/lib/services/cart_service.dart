import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/vendor.dart';

class CartItem {
  final Product product;
  final Vendor vendor;
  final int quantity;

  CartItem({
    required this.product,
    required this.vendor,
    this.quantity = 1,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      vendor: vendor,
      quantity: quantity ?? this.quantity,
    );
  }

  double get totalPrice => product.price * quantity;
}

class CartState {
  final List<CartItem> items;
  final String? vendorId; // Current cart's vendor

  CartState({this.items = const [], this.vendorId});

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({List<CartItem>? items, String? vendorId}) {
    return CartState(
      items: items ?? this.items,
      vendorId: vendorId ?? this.vendorId,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

class CartNotifier extends Notifier<CartState> {
  static const _key = 'gutzo_cart';

  @override
  CartState build() {
    _loadCart();
    return CartState();
  }

  Future<void> _loadCart() async {
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
        )).toList();
        state = CartState(items: items, vendorId: data['vendorId']);
      } catch (e) {
        // Corrupted data, clear it
        prefs.remove(_key);
      }
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'vendorId': state.vendorId,
      'items': state.items.map((item) => {
        'product': item.product.toJson(),
        'vendor': item.vendor.toJson(),
        'quantity': item.quantity,
      }).toList(),
    };
    await prefs.setString(_key, json.encode(data));
  }

  void addItem(Product product, Vendor vendor, int quantity) {
    // Cross-vendor check
    if (state.vendorId != null && state.vendorId != vendor.id && state.items.isNotEmpty) {
      state = CartState(
        items: [CartItem(product: product, vendor: vendor, quantity: quantity)],
        vendorId: vendor.id,
      );
      _saveCart();
      return;
    }

    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex != -1) {
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + quantity,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(product: product, vendor: vendor, quantity: quantity)],
        vendorId: vendor.id,
      );
    }
    _saveCart();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
    _saveCart();
  }

  void removeItem(String productId) {
    final updatedItems = state.items.where((item) => item.product.id != productId).toList();
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
