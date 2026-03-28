import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/services/order_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(activeOrderTrackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: trackingState.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderTrackingData data) {
    final restaurantLoc = data.vendorLocation != null 
        ? LatLng(data.vendorLocation!['lat'], data.vendorLocation!['lng'])
        : const LatLng(11.0168, 76.9558); // Placeholder Coimbatore
    
    final userLoc = const LatLng(11.0180, 76.9580); // Placeholder
    final riderLoc = data.rider != null && data.rider!['location'] != null
        ? LatLng(data.rider!['location']['lat'], data.rider!['location']['lng'])
        : null;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('restaurant'),
        position: restaurantLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Restaurant'),
      ),
      Marker(
        markerId: const MarkerId('user'),
        position: const LatLng(11.0180, 76.9580),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
    };

    if (riderLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: riderLoc,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Delivery Partner'),
        ),
      );
    }

    return Column(
      children: [
        // Real Google Map
        Expanded(
          flex: 2,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: riderLoc ?? restaurantLoc,
              zoom: 15,
            ),
            markers: markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),
        ),

        // Delivery Partner Info & Status
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (data.rider != null) 
                  _riderInfoCard(data.rider!),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ...data.statusFlow.asMap().entries.map((entry) {
                        final index = entry.key;
                        final step = entry.value;
                        return _timelineStep(
                          step.label,
                          '', // Subtitle could be added from backend if needed
                          step.completed,
                          step.current,
                          isLast: index == data.statusFlow.length - 1,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _riderInfoCard(Map<String, dynamic> rider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.brandGreenLight,
            radius: 24,
            child: const Icon(Icons.delivery_dining, color: AppColors.brandGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Delivery Partner', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                Text(rider['name'] ?? 'Rider Assigned', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.brandGreen),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(String title, String subtitle, bool isCompleted, bool isActive, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.brandGreen : (isActive ? Colors.white : Colors.grey[300]),
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: AppColors.brandGreen, width: 2) : null,
                ),
                child: isCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.brandGreen : Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isActive || isCompleted ? AppColors.textMain : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
