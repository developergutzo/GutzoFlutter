import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/cart_service.dart';
import '../features/checkout/checkout_notifier.dart';
import '../features/vendor/vendor_detail_screen.dart';

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
          
          widget.currentGoal != 'All'
            ? Text(
                "OPTIMIZE FOR ${widget.currentGoal.toUpperCase()}",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandGreen,
                  letterSpacing: 2,
                ),
              )
            : const SizedBox.shrink(),
            
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
          const SizedBox(height: 24),
          
          // 📦 PACK OPTIONS (Instant Selection + Navigation)
          _buildOptionCard(
            title: "5-DAY HABIT PACK",
            subtitle: "Commit to your health goal. Get a 5th meal FREE.",
            price: "₹${(widget.product.price * 4).toStringAsFixed(0)}",
            isHabit: true,
            onTap: () => _handleSelection(context, true),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            title: "JUST TODAY",
            subtitle: "A single nutrient-dense meal to fuel your day.",
            price: "₹${widget.product.price.toStringAsFixed(0)}",
            isHabit: false,
            onTap: () => _handleSelection(context, false),
          ),
        ],
      ),
    );
  }

  void _handleSelection(BuildContext context, bool isHabitSelected) {
    final user = ref.read(currentUserProvider);
    
    // 🛡️ Edge Case: Guest Login
    if (user == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to start your habit mission!'))
      );
      return;
    }

    // 🎯 Set Action Intent & Add Item to Cart
    ref.read(cartProvider.notifier).addItem(
      widget.product, 
      widget.vendor, 
      1, 
      isHabit: isHabitSelected,
    );
    
    Navigator.pop(context); // Close Drawer
    
    // 🚀 Seamless Navigation to Kitchen Menu (High Revenue Flow)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorDetailScreen(vendor: widget.vendor),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required String price,
    required bool isHabit,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isHabit ? const Color(0xFFF0FAF6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHabit ? AppColors.brandGreen : Colors.grey[200]!,
            width: isHabit ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (isHabit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "SAVE UP TO 20%",
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSub,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isHabit ? AppColors.brandGreen : AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
