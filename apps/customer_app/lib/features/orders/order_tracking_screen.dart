import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/order_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'dart:math' as math;

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with TickerProviderStateMixin {
  bool _isMapMaximized = false;
  GoogleMapController? _mapController;
  OrderTrackingData? _lastData;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTrackingOrderIdProvider.notifier).state = widget.orderId;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleMapMode() {
    setState(() {
      _isMapMaximized = !_isMapMaximized;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      _fitBounds(_lastData);
    });
  }

  void _fitBounds(OrderTrackingData? data) {
    if (_mapController == null || data == null) return;
    
    final vendorLoc = data.vendor != null && data.vendor!['latitude'] != null
        ? LatLng(double.parse(data.vendor!['latitude'].toString()), double.parse(data.vendor!['longitude'].toString()))
        : const LatLng(11.0168, 76.9558);
    
    // Default user location if address doesn't have coordinates
    final userLoc = const LatLng(11.0519, 77.0676); 
    
    final riderLoc = data.rider != null && data.rider!['location'] != null
        ? LatLng(double.parse(data.rider!['location']['lat'].toString()), double.parse(data.rider!['location']['lng'].toString()))
        : null;

    final List<LatLng> points = [vendorLoc, userLoc];
    if (riderLoc != null) points.add(riderLoc);

    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );

    // If minimized, we need more bottom padding to avoid the sheet
    if (!_isMapMaximized) {
       _mapController!.animateCamera(CameraUpdate.scrollBy(0, 150));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(activeOrderTrackingProvider(widget.orderId));

    ref.listen(activeOrderTrackingProvider(widget.orderId), (prev, next) {
      if (next.hasValue) {
        _lastData = next.value;
        if (!_isMapMaximized) {
          _fitBounds(next.value);
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: trackingState.when(
          data: (data) => _buildContent(context, data),
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1BA672))),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderTrackingData data) {
    final displayStatus = data.displayStatus;
    final isDelivered = ['delivered', 'completed'].contains(displayStatus);

    return Stack(
      children: [
        // 1. Map Layer
        _buildMap(data),

        // 2. Animated Header Panel (Match Web Style)
        if (!isDelivered) _buildHeader(data),

        // 3. Bottom Timeline Sheet (Match Web Style)
        if (!isDelivered) _buildTimelineSheet(data),

        // 5. Success Overlay (Match Web Style)
        if (isDelivered) _buildSuccessOverlay(data),
      ],
    );
  }

  Widget _buildMap(OrderTrackingData data) {
    final vendorLoc = data.vendor != null && data.vendor!['latitude'] != null
        ? LatLng(double.parse(data.vendor!['latitude'].toString()), double.parse(data.vendor!['longitude'].toString()))
        : const LatLng(11.0168, 76.9558);
    
    final userLoc = const LatLng(11.0519, 77.0676); 
    
    final riderLoc = data.rider != null && data.rider!['location'] != null
        ? LatLng(double.parse(data.rider!['location']['lat'].toString()), double.parse(data.rider!['location']['lng'].toString()))
        : null;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('kitchen'),
        position: vendorLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('user'),
        position: userLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (riderLoc != null && !['searching_rider', 'placed'].contains(data.displayStatus)) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: riderLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: vendorLoc, zoom: 14),
        markers: markers,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapType: MapType.normal,
        style: _mapStyle,
        onMapCreated: (controller) {
          _mapController = controller;
          _fitBounds(data);
        },
      ),
    );
  }

  Widget _buildHeader(OrderTrackingData data) {
    final statusText = _getStatusText(data.displayStatus);
    final isCancelled = data.displayStatus == 'cancelled';

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _isMapMaximized ? -300 : 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
        decoration: BoxDecoration(
          color: isCancelled ? const Color(0xFFEF4444) : const Color(0xFF1BA672),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.close_fullscreen, color: Colors.white, size: 18),
                      ),
                      onPressed: () {
                        context.go('/');
                      },
                    ),
                  ),
                  Text(
                    data.vendor?['name'] ?? 'Coimbatore Cafe, GK Nagar',
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
              textAlign: TextAlign.center,
            ),
            if (!isCancelled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14885E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.estimatedDelivery ?? '19 mins',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      'On time',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSheet(OrderTrackingData data) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _isMapMaximized ? -800 : 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, -10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)), margin: const EdgeInsets.only(bottom: 24)),
            // DUAL CARDS
            _buildDeliveryCard(data),
            const SizedBox(height: 12),
            _buildKitchenCard(data),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                const Icon(Icons.restaurant, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "We've asked the restaurant to not send cutlery",
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Divider(height: 40, color: Color(0xFFF1F5F9)),
            // Order ID
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Text('Order ID', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  Text('#${data.orderNumber}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [const FontFeature.tabularFigures()])),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(OrderTrackingData data) {
    final rider = data.rider;
    final status = data.displayStatus;
    final isAssigned = rider != null && ['allotted', 'arrived', 'picked_up', 'on_way', 'arrived_at_drop'].contains(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          _buildCircleIcon(Icons.person_outline_rounded, isAssigned ? const Color(0xFFE8F6F1) : const Color(0xFFF1F5F9)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DELIVERY PARTNER', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
                Text(isAssigned ? (rider['name'] ?? 'Delivery Partner') : 'Delivery Partner', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                Text(_getRiderStatusText(status), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isAssigned && rider['phone'] != null)
            _buildCallButton(rider['phone']),
        ],
      ),
    );
  }

  Widget _buildKitchenCard(OrderTrackingData data) {
    final vendor = data.vendor;
    final status = data.displayStatus;
    final isReady = ['picked_up', 'on_way', 'arrived_at_drop'].contains(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          _buildCircleIcon(Icons.storefront_outlined, const Color(0xFFF1F5F9)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KITCHEN STATUS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
                Text(vendor?['name'] ?? 'Coimbatore Cafe, GK Nagar', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                Text(_getKitchenStatusText(status), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (vendor?['phone'] != null)
            _buildCallButton(vendor!['phone']),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color bg) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: Colors.black.withOpacity(0.6)),
    );
  }

  Widget _buildCallButton(String phone) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: const Color(0xFFE8F6F1), shape: BoxShape.circle),
      child: const Icon(Icons.phone_outlined, color: Color(0xFF1BA672), size: 22),
    );
  }

  Widget _buildSuccessOverlay(OrderTrackingData data) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D6B44), Color(0xFF2EB271)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Ring
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 80 + (40 * _pulseController.value),
                    height: 80 + (40 * _pulseController.value),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3 - (0.3 * _pulseController.value)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Order Delivered!', style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Enjoy your meal from\n${data.vendor?['name'] ?? "the kitchen"}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          // Rating Card (Stub)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
            child: Column(
              children: [
                Text('RATE YOUR EXPERIENCE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 2)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => Icon(Icons.star_border, color: Colors.grey[300], size: 40)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BA672),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('DONE', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'searching_rider': return 'Finding Delivery Partner...';
      case 'allotted': return 'Delivery Partner Assigned';
      case 'arrived': return 'Delivery Partner at Kitchen';
      case 'picked_up':
      case 'on_way': return 'Out for Delivery';
      case 'arrived_at_drop':
      case 'customer_door_step': return 'Doorstep Reached';
      case 'delivered':
      case 'completed': return 'Order Delivered';
      case 'cancelled': return 'Order Cancelled';
      default: return 'Order Status';
    }
  }

  String _getRiderStatusText(String status) {
    switch (status) {
      case 'searching_rider': return 'Waiting for delivery partner';
      case 'allotted': return 'Partner assigned';
      case 'arrived': return 'Reached kitchen location';
      case 'picked_up':
      case 'on_way': return 'Partner picked up the order';
      case 'arrived_at_drop':
      case 'customer_door_step': return 'Partner reached your location';
      default: return 'Searching for partner...';
    }
  }

  String _getKitchenStatusText(String status) {
    if (['picked_up', 'on_way', 'arrived_at_drop'].contains(status)) return 'Food handed over to partner';
    if (status == 'ready' || status == 'arrived') return 'Order is ready';
    return 'Order is being prepared';
  }

  static const String _mapStyle = '[{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]}]';
}
