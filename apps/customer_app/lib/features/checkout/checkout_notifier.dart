import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/address.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/services/auth_service.dart';

class CheckoutState {
  final List<UserAddress> addresses;
  final UserAddress? selectedAddress;
  final bool isLoadingAddresses;
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
    this.addresses = const [],
    this.selectedAddress,
    this.isLoadingAddresses = false,
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
    List<UserAddress>? addresses,
    UserAddress? selectedAddress,
    bool? isLoadingAddresses,
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
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      isLoadingAddresses: isLoadingAddresses ?? this.isLoadingAddresses,
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

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Watch cart to update taxes whenever quantities/items change
    ref.listen(cartProvider, (_, __) => updateTaxes());
    
    // Trigger address fetch on first build
    Future.microtask(() => fetchAddresses());
    return CheckoutState();
  }

  NodeApiService get _api => ref.read(nodeApiServiceProvider);

  Future<void> fetchAddresses() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(isLoadingAddresses: true);
    try {
      final res = await _api.getUserAddresses(user.phone);
      if (res['success'] == true) {
        final List<dynamic> data = res['data'] ?? [];
        final addresses = data.map((json) => UserAddress.fromJson(json)).toList();
        
        UserAddress? selected;
        if (addresses.isNotEmpty) {
          selected = addresses.any((a) => a.isDefault) 
              ? addresses.firstWhere((a) => a.isDefault)
              : addresses.first;
        }

        state = state.copyWith(
          addresses: addresses,
          selectedAddress: selected,
          isLoadingAddresses: false,
        );
        if (state.selectedAddress != null) {
          checkServiceability();
        }
      }
    } catch (e) {
      state = state.copyWith(isLoadingAddresses: false, error: e.toString());
    }
  }

  void selectAddress(UserAddress address) {
    state = state.copyWith(selectedAddress: address);
    checkServiceability();
  }

  Future<void> checkServiceability() async {
    final cart = ref.read(cartProvider);
    final selectedAddress = state.selectedAddress;
    if (cart.items.isEmpty || selectedAddress == null) return;

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
      
      final drop = {
        "address": selectedAddress.fullAddress,
        "latitude": selectedAddress.latitude,
        "longitude": selectedAddress.longitude,
      };

      final res = await _api.getDeliveryServiceability(pickup, drop);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        
        // Handle nested 'value' object from Shadowfax API, matching webapp logic
        final nestedData = data['value'] is Map ? data['value'] as Map : null;
        
        // Optimistic default to true for serviceability if not explicitly false, matching web
        final isServiceable = data['is_serviceable'] ?? nestedData?['is_serviceable'] ?? true;
        
        // Map delivery fee and ETA from either top level or nested value
        final deliveryFee = (data['total_amount'] ?? nestedData?['total_amount'] ?? 100).toDouble();
        final eta = data['pickup_eta'] ?? nestedData?['pickup_eta']?.toString();

        state = state.copyWith(
          isServiceable: isServiceable,
          deliveryFee: deliveryFee,
          eta: eta,
          isCheckingServiceability: false,
        );
      } else {
        state = state.copyWith(
          isServiceable: false,
          isCheckingServiceability: false,
          deliveryFee: 100,
        );
      }
    } catch (e) {
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
    final currentState = state;
    
    if (user == null || cart.items.isEmpty || currentState.selectedAddress == null) {
      return "Missing required information";
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
      final orderData = {
        "vendor_id": cart.vendorId,
        "items": cart.items.map((item) => {
          "product_id": item.product.id,
          "quantity": item.quantity,
        }).toList(),
        "delivery_address": currentState.selectedAddress!.toJson(),
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

final checkoutProvider = NotifierProvider<CheckoutNotifier, CheckoutState>(() => CheckoutNotifier());
