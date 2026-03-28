import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../orders/order_tracking_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final double _deliveryFee = 50.0;
  final double _platformFee = 10.0;
  final double _gstRate = 0.05; // 5%
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.subtotal;
    final gstItems = subtotal * _gstRate;
    final total = subtotal + gstItems + _deliveryFee + _platformFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Address Card
                  _sectionHeader('Delivery Address'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const ListTile(
                      leading: Icon(Icons.location_on, color: AppColors.brandGreen),
                      title: Text('HOME', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Coimbatore, Tamil Nadu, 641001'),
                      trailing: Text('Change', style: TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Order Summary
                  _sectionHeader('Order Summary'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ...cart.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item.product.name} × ${item.quantity}'),
                                    Text('₹${item.totalPrice}'),
                                  ],
                                ),
                              )),
                          const Divider(),
                          _priceRow('Subtotal', subtotal),
                          _priceRow('GST (5%)', gstItems),
                          _priceRow('Delivery Fee', _deliveryFee),
                          _priceRow('Platform Fee', _platformFee),
                          const Divider(),
                          _priceRow('Total', total, isBold: true, color: AppColors.brandGreen),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Method
                  _sectionHeader('Payment Method'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        RadioListTile(
                          value: 'upi',
                          groupValue: 'upi',
                          onChanged: (v) {},
                          title: const Text('UPI (Google Pay, PhonePe)'),
                          secondary: const Icon(Icons.account_balance_wallet_outlined),
                          activeColor: AppColors.brandGreen,
                        ),
                        RadioListTile(
                          value: 'card',
                          groupValue: 'upi',
                          onChanged: (v) {},
                          title: const Text('Credit / Debit Card'),
                          secondary: const Icon(Icons.credit_card),
                          activeColor: AppColors.brandGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Spacing for bottom button
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePlaceOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('Pay ₹$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePlaceOrder() async {
    setState(() => _isLoading = true);
    try {
      final cart = ref.read(cartProvider);
      final api = ref.read(nodeApiServiceProvider);

      // 1. Create Order
      final orderData = {
        "vendor_id": cart.vendorId,
        "items": cart.items.map((item) => {
          "product_id": item.product.id,
          "quantity": item.quantity,
          "price": item.product.price,
        }).toList(),
        "delivery_address": {
          "address": "Coimbatore, Tamil Nadu, 641001",
          "tag": "HOME",
          "lat": 11.0168,
          "lng": 76.9558
        },
        "delivery_phone": "9944751745",
        "payment_method": "upi",
        "order_source": "app",
        "mock_shadowfax": true
      };

      final orderResponse = await api.createOrder(orderData);
      final orderNumber = orderResponse['data']['order_number'];
      final orderId = orderResponse['data']['id'];

      // 2. Trigger Mock Payment
      await api.triggerMockPayment(orderNumber);

      // 3. Clear Cart & Show Success
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        _showSuccessDialog(orderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSub)),
    );
  }

  Widget _priceRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('₹$value', style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.brandGreen, size: 80),
            const SizedBox(height: 16),
            Text('Order Placed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your meal is being prepared.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSub)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => OrderTrackingScreen(orderId: orderId)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Track Order'),
            ),
          ],
        ),
      ),
    );
  }
}
