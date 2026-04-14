import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/vendor/vendor_detail_screen.dart';

import 'modern_dialog.dart';

class CartStrip extends ConsumerWidget {
  final bool isPremium;
  final bool? filterHabit; // NEW: null=all, true=Habit only, false=Today only

  const CartStrip({
    super.key, 
    this.isPremium = false,
    this.filterHabit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    
    // Filter items based on the requested mode
    final filteredItems = cart.items.where((item) => filterHabit == null || item.isHabit == filterHabit).toList();
    if (filteredItems.isEmpty) return const SizedBox.shrink();

    // Compute localized stats
    final totalItems = filteredItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final subtotal = filteredItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final vendor = filteredItems.first.vendor;

    return Responsive(
      mobile: _buildMobileCart(context, ref, vendor, totalItems, subtotal),
      desktop: _buildWebCart(context, ref, vendor, totalItems, subtotal),
    );
  }

  Widget _buildWebCart(BuildContext context, WidgetRef ref, dynamic vendor, int totalItems, double subtotal) {
    final bool isHabitStrip = filterHabit == true;
    final Color primaryColor = isHabitStrip ? const Color(0xFF008080) : AppColors.brandGreen;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: Container(
            width: 700,
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(42),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                )
              ],
              border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                // Left: Item Count Indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(
                          isHabitStrip ? Icons.auto_awesome : Icons.shopping_bag_outlined, 
                          color: primaryColor, 
                          size: 28
                        ),
                        if (totalItems > 0)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              totalItems.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Center-Left: Vendor Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHabitStrip ? "Habit Plan: ${vendor.name}" : vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isHabitStrip ? 'Adding to your result-focused mission' : 'One-time healthy additions',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Center-Right: Total Amount
                Container(
                  height: 40,
                  width: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isHabitStrip ? 'PLAN TOTAL' : 'TOTAL PAYABLE', 
                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                    ),
                    Text(
                      '₹${subtotal.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textMain, height: 1.1),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Right: Checkout Button
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
                    minimumSize: const Size(180, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: Row(
                    children: [
                      const Text('VIEW CART', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Close Button to Clear Cart
                GestureDetector(
                  onTap: () => _showClearCartDialog(context, ref, vendor.name),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEFEB),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 20, color: Color(0xFFE64A19)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCart(BuildContext context, WidgetRef ref, dynamic vendor, int totalItems, double subtotal) {
    final bool isHabitStrip = filterHabit == true;
    final Color primaryColor = isHabitStrip ? const Color(0xFF008080) : AppColors.brandGreen;

    if (isPremium) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor))),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
              border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Row(
              children: [
                // Image indicator or icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isHabitStrip ? Icons.auto_awesome : Icons.restaurant, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Vendor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isHabitStrip ? "Habit Mission" : "Just Today",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Checkout Button
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalItems item${totalItems > 1 ? 's' : ''} | ₹${subtotal.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                      const Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showClearCartDialog(context, ref, vendor.name),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEFEB),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 16, color: Color(0xFFE64A19)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: isHabitStrip 
              ? LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.8)])
              : null,
            color: isHabitStrip ? null : primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isHabitStrip ? Icons.auto_awesome : Icons.shopping_basket, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHabitStrip ? 'Habit Mission' : 'Just Today',
                        style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      Text(
                        '$totalItems item${totalItems > 1 ? 's' : ''} added',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'View Cart',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => ModernDialog(
        title: 'Clear cart?',
        message: 'Are you sure you want to remove these items from $vendorName?',
        primaryLabel: 'Clear',
        secondaryLabel: 'Cancel',
        isDestructive: true,
        onPrimary: () {
          if (filterHabit != null) {
            ref.read(cartProvider.notifier).clearByType(filterHabit!);
          } else {
            ref.read(cartProvider.notifier).clear();
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}
