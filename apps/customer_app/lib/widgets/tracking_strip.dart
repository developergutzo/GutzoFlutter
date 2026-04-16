import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/order_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:go_router/go_router.dart';

class TrackingStrip extends ConsumerWidget {
  const TrackingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersAsync = ref.watch(liveActiveOrdersProvider);

    return activeOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) return const SizedBox.shrink();
        return _buildMultiOrderStrip(context, orders);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMultiOrderStrip(BuildContext context, List<Order> orders) {
    final bool hasMany = orders.length >= 3;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMany)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'ACTIVE ORDERS (${orders.length})',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                  letterSpacing: 1.2,
                ),
              ),
            )
          else
            const SizedBox(height: 16),
          
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: orders.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return _TrackingCard(order: orders[index]);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TrackingCard extends ConsumerWidget {
  final Order order;
  const _TrackingCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(activeOrderTrackingProvider(order.id));

    return trackingState.when(
      data: (data) => _buildCard(context, data),
      loading: () => _buildShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context, OrderTrackingData data) {
    final status = data.displayStatus;
    final vendorName = data.vendor?['name'] ?? 'Restaurant';
    
    String displayStatusText;
    IconData statusIcon;
    Color statusColor = const Color(0xFF1BA672);

    if (['pending', 'created', 'placed', 'searching_rider'].contains(status)) {
      displayStatusText = 'SEARCHING';
      statusIcon = Icons.search_rounded;
    } else if (['accepted', 'preparing', 'allotted', 'driver_assigned', 'rider_assigned'].contains(status)) {
      displayStatusText = 'PREPARING';
      statusIcon = Icons.restaurant_rounded;
    } else if (['collected', 'picked_up', 'on_way', 'out_for_delivery'].contains(status)) {
      displayStatusText = 'ON THE WAY';
      statusIcon = Icons.directions_bike_rounded;
    } else if (['delivered', 'completed'].contains(status)) {
      displayStatusText = 'DELIVERED';
      statusIcon = Icons.check_circle_rounded;
    } else {
      displayStatusText = status.toUpperCase();
      statusIcon = Icons.location_on_rounded;
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  vendorName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#${order.id.toUpperCase().substring(0, 12)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      displayStatusText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Maximize Button
          GestureDetector(
            onTap: () => context.go('/tracking/${order.id}'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.open_in_full_rounded, color: AppColors.textMain, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
