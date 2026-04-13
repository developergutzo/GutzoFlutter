import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/cart_service.dart';
import '../features/checkout/checkout_notifier.dart';
import '../features/checkout/checkout_screen.dart';

class HabitSelectionDrawer extends ConsumerStatefulWidget {
  final Vendor vendor;
  final Product product;
  final String currentGoal;

  const HabitSelectionDrawer({
    super.key,
    required this.vendor,
    required this.product,
    required this.currentGoal,
  });

  static void show(BuildContext context, Vendor vendor, Product product, String currentGoal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HabitSelectionDrawer(
        vendor: vendor,
        product: product,
        currentGoal: currentGoal,
      ),
    );
  }

  @override
  ConsumerState<HabitSelectionDrawer> createState() => _HabitSelectionDrawerState();
}

class _HabitSelectionDrawerState extends ConsumerState<HabitSelectionDrawer> {
  bool isHabitSelected = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Commit to the Result",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Most people choosing ${widget.currentGoal} pick the 5-Day Pack.",
              style: const TextStyle(
                color: AppColors.brandGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildOption(
            title: "Just Today",
            subtitle: "One-time healthy fuel",
            price: "₹299",
            isSelected: !isHabitSelected,
            onTap: () => setState(() => isHabitSelected = false),
          ),
          const SizedBox(height: 16),
          _buildOption(
            title: "5-Day Habit Pack",
            subtitle: "Lock in your progress & Save ₹150",
            price: "₹1199",
            isSelected: isHabitSelected,
            onTap: () => setState(() => isHabitSelected = true),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final user = ref.read(currentUserProvider);
                
                // 🛡️ Edge Case: Guest Login
                if (user == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please login to start your habit mission!'))
                  );
                  return;
                }

                // 🎯 Set Action Intent
                ref.read(checkoutProvider.notifier).setHabitSubscription(isHabitSelected, goal: widget.currentGoal);
                
                // 🛒 Add Item to Cart
                ref.read(cartProvider.notifier).addItem(widget.product, widget.vendor, 1);
                
                Navigator.pop(context); // Close Drawer
                
                // 🚀 Navigation strategy: If habit, go to checkout. If one-time, maybe stay? 
                // Hormozi says: "Assume the Sale." Always go to checkout for higher velocity.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                "CONFIRM CHOICE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.brandGreen : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? AppColors.brandGreen.withValues(alpha: 0.02) : Colors.white,
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const Spacer(),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
