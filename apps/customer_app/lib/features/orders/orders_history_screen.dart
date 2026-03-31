import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/order_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'order_tracking_screen.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  final Set<String> _expandedOrderIds = {};

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedOrderIds.contains(id)) {
        _expandedOrderIds.remove(id);
      } else {
        _expandedOrderIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      body: ordersAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState(err.toString()),
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            color: AppColors.brandGreen,
            onRefresh: () async {
              return ref.refresh(ordersProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildOrderCard(context, orders[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 60, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error Loading Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textMain)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.refresh(ordersProvider),
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Orders Yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              'Your order history will appear here once you place your first order.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSub),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text(
                  'Order More Delicious Meals',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final bool isExpanded = _expandedOrderIds.contains(order.id);
    final bool isDelivered = order.status == 'delivered' || order.status == 'completed';
    final bool isPaymentFailed = (order.paymentStatus == 'pending' || order.paymentStatus == 'failed') && order.paymentMethod != 'cod';
    
    // Status resolution mapping
    String displayStatusText;
    Color statusBgColor;
    Color statusTextColor;

    if (isPaymentFailed) {
      displayStatusText = 'PAYMENT FAILED';
      statusBgColor = Colors.red.shade50;
      statusTextColor = Colors.red.shade700;
    } else if (order.status == 'confirmed') {
      displayStatusText = 'WAITING FOR ACCEPTANCE';
      statusBgColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade700;
    } else if (order.status == 'arrived_at_drop') {
      displayStatusText = 'VALET AT DOORSTEP';
      statusBgColor = Colors.blue.shade50;
      statusTextColor = Colors.blue.shade600;
    } else if (order.status == 'reached_location') {
      displayStatusText = 'RIDER AT RESTAURANT';
      statusBgColor = Colors.blue.shade50;
      statusTextColor = Colors.blue.shade600;
    } else if (order.status == 'delivered' || order.status == 'completed') {
      displayStatusText = order.status.toUpperCase();
      statusBgColor = Colors.green.shade50;
      statusTextColor = Colors.green.shade700;
    } else if (order.status == 'cancelled' || order.status == 'rejected') {
      displayStatusText = order.status.toUpperCase();
      statusBgColor = Colors.red.shade50;
      statusTextColor = Colors.red.shade700;
    } else if (order.status == 'preparing' || order.status == 'on_way') {
      displayStatusText = order.status.toUpperCase().replaceAll('_', ' ');
      statusBgColor = Colors.blue.shade50;
      statusTextColor = Colors.blue.shade600;
    } else {
      displayStatusText = order.status.toUpperCase().replaceAll('_', ' ');
      statusBgColor = Colors.grey.shade100;
      statusTextColor = Colors.grey.shade700;
    }

    return GestureDetector(
      onTap: () => _toggleExpanded(order.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDelivered ? AppColors.brandGreen.withValues(alpha: 0.03) : Colors.white,
          border: Border.all(
            color: isDelivered ? AppColors.brandGreen.withValues(alpha: 0.3) : Colors.grey.shade200,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDelivered ? AppColors.brandGreen.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: isDelivered ? AppColors.brandGreen : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ID & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id.substring(0, 8)}',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                displayStatusText,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusTextColor, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Vendor Name
                        Text(
                          order.vendor?.name ?? 'Unknown Vendor',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Meta Info
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: AppColors.textSub),
                            const SizedBox(width: 4),
                            Text(
                              "${DateFormat('dd/MM/yyyy • hh:mm a').format(order.createdAt)}",
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expanding Breakdowns
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 16),
                
                // Item List
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text('${item.quantity}x', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.productName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMain)),
                      ),
                      Text('₹${item.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMain, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),

                const SizedBox(height: 8),

                // Financial Breakdown Gray Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      _buildBreakdownRow('Subtotal', order.subtotal),
                      if (order.deliveryFee > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Delivery', order.deliveryFee),
                      ],
                      if (order.platformFee > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Platform Fee', order.platformFee),
                      ],
                      if (order.packagingFee > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Packaging Fee', order.packagingFee),
                      ],
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Discount', -order.discountAmount, isDiscount: true),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Colors.black12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Grand Total', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                          Text('₹${order.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                        ],
                      )
                    ],
                  ),
                )
              ],

              const SizedBox(height: 16),

              // Action Bar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isExpanded ? AppColors.textMain : AppColors.textSub,
                        backgroundColor: isExpanded ? Colors.grey.shade100 : Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () => _toggleExpanded(order.id),
                      child: Text(isExpanded ? 'Collapse' : 'Details', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  if (isDelivered) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMain,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          // Invoice Logic Mock (Would Launch URL / Download natively)
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice fetching is not natively supported yet.')));
                        },
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: Text('Invoice', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],

                  if (isPaymentFailed && order.status != 'cancelled' && order.status != 'rejected') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                          // Resurrect payment flow logic
                        },
                        child: Text('Retry Payment', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else if (!['cancelled', 'rejected', 'delivered', 'completed'].contains(order.status)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                           Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (context) => OrderTrackingScreen(orderId: order.id)),
                          );
                        },
                        child: Text('Track Order', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String title, double amount, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub)),
        Text(
          '${isDiscount ? '-' : ''}₹${amount.abs().toStringAsFixed(2)}', 
          style: GoogleFonts.poppins(fontSize: 12, color: isDiscount ? Colors.green.shade700 : AppColors.textSub, fontWeight: isDiscount ? FontWeight.w600 : FontWeight.w400)
        ),
      ],
    );
  }
}
