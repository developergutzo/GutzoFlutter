import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/address.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:flutter/foundation.dart';

class CheckoutState {
  final bool isCheckingServiceability;
  final double deliveryFee;
  final double platformFee;
  final double packagingFee;
  final double gst;
  final String? eta;
  final bool isServiceable;
  final bool isProcessing;
  final String? error;
  final String devEnvironment;
  final bool useFreeFees;
  final String orderNote;
  final bool dontAddCutlery;
  final bool isDonationChecked;
  final double donationAmount;

  CheckoutState({
    this.isCheckingServiceability = false,
    this.deliveryFee = 0,
    this.platformFee = 10,
    this.packagingFee = 0,
    this.gst = 0,
    this.eta,
    this.isServiceable = true,
    this.isProcessing = false,
    this.error,
    this.devEnvironment = 'full_mock',
    this.useFreeFees = false,
    this.orderNote = '',
    this.dontAddCutlery = false,
    this.isDonationChecked = false,
    this.donationAmount = 3.0,
  });

  CheckoutState copyWith({
    bool? isCheckingServiceability,
    double? deliveryFee,
    double? platformFee,
    double? packagingFee,
    double? gst,
    String? eta,
    bool? isServiceable,
    bool? isProcessing,
    String? error,
    String? devEnvironment,
    bool? useFreeFees,
    String? orderNote,
    bool? dontAddCutlery,
    bool? isDonationChecked,
    double? donationAmount,
  }) {
    return CheckoutState(
      isCheckingServiceability: isCheckingServiceability ?? this.isCheckingServiceability,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      platformFee: platformFee ?? this.platformFee,
      packagingFee: packagingFee ?? this.packagingFee,
      gst: gst ?? this.gst,
      eta: eta ?? this.eta,
      isServiceable: isServiceable ?? this.isServiceable,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
      devEnvironment: devEnvironment ?? this.devEnvironment,
      useFreeFees: useFreeFees ?? this.useFreeFees,
      orderNote: orderNote ?? this.orderNote,
      dontAddCutlery: dontAddCutlery ?? this.dontAddCutlery,
      isDonationChecked: isDonationChecked ?? this.isDonationChecked,
      donationAmount: donationAmount ?? this.donationAmount,
    );
  }
}

class CheckoutNotifier extends AutoDisposeNotifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Watch cart to update taxes whenever quantities/items change
    ref.listen(cartProvider, (_, __) => updateTaxes());
    
    // Listen to location changes to update serviceability immediately
    ref.listen(locationProvider, (previous, next) {
      if (next.location != null) {
        print('📍 [Checkout] Location detected/changed: ${next.location?.tag ?? next.location?.areaName}. Re-calculating...');
        checkServiceability();
      } else {
        // If location becomes null (e.g. deleted), reset serviceability
        state = state.copyWith(isCheckingServiceability: false);
      }
    });

    // Initial check if location is already available
    final initialLocation = ref.read(locationProvider).location;
    if (initialLocation != null) {
      Future.microtask(() => checkServiceability());
    }
    
    return CheckoutState(isCheckingServiceability: initialLocation != null);
  }

  NodeApiService get _api => ref.read(nodeApiServiceProvider);

  // No longer needed as we rely on global locationProvider
  void selectAddress(UserAddress address) {
    // Handled by global location sync
  }

  Future<void> checkServiceability() async {
    final cart = ref.read(cartProvider);
    final location = ref.read(locationProvider).location;

    if (cart.items.isEmpty || location == null) {
      print('🚫 [Checkout] checkServiceability skipped: cart empty=${cart.items.isEmpty}, location null=${location == null}');
      state = state.copyWith(isCheckingServiceability: false);
      return;
    }

    print('📡 [Checkout] checkServiceability START');
    state = state.copyWith(isCheckingServiceability: true);
    try {
      final vendorId = cart.vendorId!;
      final vendorRes = await _api.getVendor(vendorId);
      final vendorData = vendorRes['data'];
      
      final pickup = {
        "address": vendorData['location'] ?? vendorData['name'],
        "latitude": vendorData['latitude'],
        "longitude": vendorData['longitude'],
      };
      
      // Coordinates from single source of truth
      final drop = {
        "address": location.formattedAddress ?? "Delivery Location",
        "latitude": location.latitude,
        "longitude": location.longitude,
      };

      print('📡 [Checkout] Pickup: $pickup');
      print('📡 [Checkout] Drop: $drop');

      if (drop['latitude'] == 0.0 || drop['longitude'] == 0.0) {
         print('❌ [Checkout] Missing coordinates (0.0), cannot check serviceability');
         state = state.copyWith(isCheckingServiceability: false);
         return;
      }

      final res = await _api.getDeliveryServiceability(pickup, drop);
      print('📡 [Checkout] Serviceability RAW response: $res');
      
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        print('📡 [Checkout] data keys: ${data.keys.toList()}');
        
        // Handle nested 'value' object from Shadowfax API, matching webapp logic
        final nestedData = data['value'] is Map ? data['value'] as Map : null;
        print('📡 [Checkout] nestedData: $nestedData');
        
        // Optimistic default to true for serviceability if not explicitly false, matching web
        final isServiceable = data['is_serviceable'] ?? nestedData?['is_serviceable'] ?? true;
        
        // Map delivery fee and ETA from either top level or nested value
        // Match webapp logic: res.data.total_amount || 100 (treats 0 as falsy)
        double deliveryFee = (data['total_amount'] ?? nestedData?['total_amount'] ?? 100).toDouble();
        if (deliveryFee == 0) deliveryFee = 100;

        final eta = data['pickup_eta'] ?? nestedData?['pickup_eta']?.toString();

        print('✅ [Checkout] PARSED: serviceable=$isServiceable, deliveryFee=$deliveryFee, eta=$eta');

        state = state.copyWith(
          isServiceable: isServiceable,
          deliveryFee: deliveryFee,
          eta: eta,
          isCheckingServiceability: false,
        );
      } else {
        print('❌ [Checkout] API returned success=false');
        state = state.copyWith(
          isServiceable: false,
          isCheckingServiceability: false,
          deliveryFee: 100,
        );
      }
    } catch (e) {
      print('❌ [Checkout] checkServiceability ERROR: $e');
      state = state.copyWith(
        isServiceable: false, // Explicitly set to false on error
        isCheckingServiceability: false, 
        deliveryFee: 100,
      );
    }
    updateTaxes();
  }

  void updateTaxes() {
    final cart = ref.read(cartProvider);
    final itemTotal = cart.subtotal;
    final devFee = state.useFreeFees ? 0.0 : state.deliveryFee;
    final platFee = state.useFreeFees ? 0.0 : state.platformFee;
    final packFee = state.packagingFee;
    
    // Web/Backend Logic: 
    // 5% GST on Items + Packaging
    // 18% GST on Delivery + Platform
    final itemGst = (itemTotal + packFee) * 0.05;
    final feeGst = (devFee + platFee) * 0.18;
    
    // Use 2 decimal precision to match web UI
    final totalGst = double.parse((itemGst + feeGst).toStringAsFixed(2));
    
    state = state.copyWith(gst: totalGst);
  }

  void setDevEnvironment(String env) {
    state = state.copyWith(devEnvironment: env);
  }

  void setUseFreeFees(bool value) {
    state = state.copyWith(useFreeFees: value);
    updateTaxes();
  }

  void setOrderNote(String note) {
    state = state.copyWith(orderNote: note);
  }

  void toggleCutlery() {
    state = state.copyWith(dontAddCutlery: !state.dontAddCutlery);
  }

  void toggleDonation() {
    state = state.copyWith(isDonationChecked: !state.isDonationChecked);
  }

  Future<String?> placeOrder() async {
    final user = ref.read(currentUserProvider);
    final cart = ref.read(cartProvider);
    final location = ref.read(locationProvider).location;
    final currentState = state;
    
    if (user == null || cart.items.isEmpty || location == null) {
      return "Missing required information (User, Cart, or Location)";
    }

    // Map devEnvironment to internal flags exactly like webapp CheckoutPage.tsx
    bool useMockPayment = false;
    bool useMockShadowfax = false;
    
    switch (currentState.devEnvironment) {
      case 'full_mock':
        useMockPayment = true;
        useMockShadowfax = true;
        break;
      case 'real_pay_mock_del':
        useMockPayment = false;
        useMockShadowfax = true;
        break;
      case 'mock_pay_real_del':
        useMockPayment = true;
        useMockShadowfax = false;
        break;
      case 'production':
        useMockPayment = false;
        useMockShadowfax = false;
        break;
    }

    state = state.copyWith(isProcessing: true);
    try {
      // 📍 Final Sentinel Check: Re-verify serviceability right before creating order
      await checkServiceability();
      if (!state.isServiceable) {
        state = state.copyWith(isProcessing: false, error: "Kitchen just became unserviceable. Please try again later.");
        return "Kitchen just became unserviceable";
      }

      final orderData = {
        "vendor_id": cart.vendorId,
        "items": cart.items.map((item) => {
          "product_id": item.product.id,
          "quantity": item.quantity,
        }).toList(),
        "delivery_address": {
          "full_address": location.formattedAddress ?? "GPS Location",
          "city": location.city,
          "state": location.state,
          "country": location.country,
          "latitude": location.latitude,
          "longitude": location.longitude,
          "type": "other",
          "label": location.tag,
          "street": "", // GPS doesn't always have street
        },
        "delivery_phone": user.phone,
        "payment_method": "wallet",
        "special_instructions": [
          if (currentState.orderNote.isNotEmpty) currentState.orderNote,
          if (useMockShadowfax) "[MOCK_SFX]"
        ].join(' ').trim(),
        "mock_shadowfax": useMockShadowfax,
        "delivery_fee": currentState.useFreeFees ? 0 : currentState.deliveryFee,
        "platform_fee": currentState.useFreeFees ? 0 : currentState.platformFee,
        "taxes": currentState.gst.toStringAsFixed(2),
        "tip_amount": currentState.isDonationChecked ? currentState.donationAmount : 0,
        "order_source": "app",
      };

      final res = await _api.createOrder(orderData: orderData, overridePhone: user.phone);
      if (res['success'] == true) {
        final orderObj = res['data']['order'];
        final orderNumber = orderObj['order_number'];
        final orderId = orderObj['id'];

        if (useMockPayment) {
          await _api.triggerMockPayment(
            orderNumber, 
            mockShadowfax: useMockShadowfax,
            overridePhone: user.phone
          );
        }
        
        ref.read(cartProvider.notifier).clear();
        state = state.copyWith(isProcessing: false);
        return orderId;
      } else {
        state = state.copyWith(isProcessing: false);
        return res['message'] ?? "Order creation failed";
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      return e.toString();
    }
  }
}

final checkoutProvider = NotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(() => CheckoutNotifier());
