import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'replace_cart_dialog.dart';
import 'habit_selection_drawer.dart';
import '../features/home/home_screen.dart';

class QuantitySelector extends ConsumerWidget {
  final Product product;
  final Vendor vendor;

  const QuantitySelector({
    super.key,
    required this.product,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((item) => item.product.id == product.id).firstOrNull;
    final isServiceable = vendor.isServiceable ?? true;
    final quantity = cartItem?.quantity ?? 0;

    return IgnorePointer(
      ignoring: !isServiceable,
      child: Opacity(
        opacity: isServiceable ? 1.0 : 0.6,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: quantity == 0
              ? _buildAddButton(context, ref, cart, isServiceable)
              : _buildSelector(ref, quantity, isServiceable),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, CartState cart, bool isServiceable) {
    return SizedBox(
      key: const ValueKey('add_button'),
      width: 100,
      height: 40,
      child: ElevatedButton(
        onPressed: isServiceable ? () {
          // Check for cross-vendor conflict
          if (cart.vendorId != null && cart.vendorId != vendor.id && cart.items.isNotEmpty) {
            final activeVendorName = ref.read(cartProvider.notifier).activeVendorName ?? 'another kitchen';
            showDialog(
              context: context,
              builder: (context) => ReplaceCartDialog(
                oldVendorName: activeVendorName,
                newVendorName: vendor.name,
                onReplace: () {
                  ref.read(cartProvider.notifier).addItem(product, vendor, 1, forceClear: true);
                },
              ),
            );
          } else {
            // 🎯 NEW: If cart is empty, trigger the Habit Drawer
            if (cart.items.isEmpty) {
              final currentGoal = ref.read(homeFilterProvider);
              HabitSelectionDrawer.show(context, vendor, product, currentGoal);
            } else {
              ref.read(cartProvider.notifier).addItem(product, vendor, 1);
            }
          }
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: isServiceable ? AppColors.brandGreen : Colors.grey,
          elevation: isServiceable ? 2 : 0,
          shadowColor: Colors.black.withOpacity(0.1),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isServiceable ? AppColors.brandGreen : Colors.grey[300]!, width: 1.2),
          ),
        ),
        child: Text(
          isServiceable ? 'ADD' : 'UNAVAILABLE',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: isServiceable ? 13 : 10,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildSelector(WidgetRef ref, int quantity, bool isServiceable) {
    return Container(
      key: const ValueKey('quantity_selector'),
      width: 100,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isServiceable ? AppColors.brandGreen : Colors.grey[300]!, width: 1.2),
        boxShadow: [
          if (isServiceable)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            icon: Icons.remove,
            color: isServiceable ? AppColors.brandGreen : Colors.grey,
            onTap: isServiceable ? () => ref.read(cartProvider.notifier).updateQuantity(product.id, quantity - 1) : null,
          ),
          Text(
            '$quantity',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isServiceable ? AppColors.brandGreen : Colors.grey,
            ),
          ),
          _buildActionButton(
            icon: Icons.add,
            color: isServiceable ? AppColors.brandGreen : Colors.grey,
            onTap: isServiceable ? () => ref.read(cartProvider.notifier).updateQuantity(product.id, quantity + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 40,
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}
