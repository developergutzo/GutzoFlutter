import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../features/checkout/checkout_screen.dart';

class CartStrip extends ConsumerWidget {
  const CartStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    
    if (cart.items.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CheckoutScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.brandGreen,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.totalItems} Items',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    '₹${cart.subtotal}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'VIEW CART',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
