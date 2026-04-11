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
  const CartStrip({super.key, this.isPremium = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.items.isEmpty) return const SizedBox.shrink();

    return Responsive(
      mobile: _buildMobileCart(context, ref, cart),
      desktop: _buildWebCart(context, ref, cart),
    );
  }

  Widget _buildWebCart(BuildContext context, WidgetRef ref, dynamic cart) {
    final vendor = cart.items.first.vendor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: Container(
            width: 700, // Substantial desktop presence
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(42), // Pure pill shape
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                )
              ],
              border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                // Left: Item Count Indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: AppColors.brandGreen, size: 28),
                        if (cart.totalItems > 0)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.brandGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              cart.totalItems.toString(),
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
                        vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Items from this kitchen are in your cart',
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
                    const Text('TOTAL PAYABLE', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    Text(
                      '₹${cart.subtotal.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textMain, height: 1.1),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Right: Checkout Button
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
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
                const SizedBox(width: 6), // End padding for pill shape closure
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCart(BuildContext context, WidgetRef ref, dynamic cart) {
    if (isPremium) {
      final vendor = cart.items.first.vendor;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          ),
          child: Row(
            children: [
              // Vendor Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(vendor.image.isNotEmpty ? vendor.image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Vendor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vendor.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VendorDetailScreen(vendor: vendor),
                          ),
                        );
                      },
                      child: Text(
                        'View Full Menu',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSub,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Checkout Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''} | ₹${cart.subtotal.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      'Checkout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Close Button
              GestureDetector(
                onTap: () => _showClearCartDialog(context, ref, vendor.name),
                child: Container(
                  width: 28,
                  height: 28,
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
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CheckoutScreen()),
          );
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.brandGreen,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''} added',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    'View Cart',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '>',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
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
        message: 'Are you sure you want to clear your cart from $vendorName?',
        primaryLabel: 'Clear',
        secondaryLabel: 'Cancel',
        isDestructive: true,
        onPrimary: () {
          ref.read(cartProvider.notifier).clear();
          Navigator.pop(context);
        },
      ),
    );
  }
}
