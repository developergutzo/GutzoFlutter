import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/order_service.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'order_tracking_screen.dart';

class OrdersHistoryScreen extends ConsumerWidget {
  const OrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: ordersAsync.when(
        data: (orders) => orders.isEmpty
            ? const Center(child: Text('No orders found'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) => _orderCard(context, orders[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OrderTrackingScreen(orderId: order.id)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.vendor?.name ?? 'Unknown Store', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(DateFormat('dd MMM, hh:mm a').format(order.createdAt),
                        style: const TextStyle(color: AppColors.textSub, fontSize: 12)),
                    ],
                  ),
                  _statusBadge(order.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.items.map((i) => '${i.quantity} x ${i.productName}').join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textMain),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('₹${order.totalAmount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.blue;
    if (status.toLowerCase().contains('delivered')) color = AppColors.brandGreen;
    if (status.toLowerCase().contains('cancel')) color = Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
