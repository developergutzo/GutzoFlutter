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
import '../features/checkout/checkout_notifier.dart';

class QuantitySelector extends ConsumerWidget {
  final Product product;
  final Vendor vendor;
  final bool isFullWidth;
  final bool navigateToVendor; // 🎯 NEW: Control navigation after habit selection

  const QuantitySelector({
    super.key,
    required this.product,
    required this.vendor,
    this.isFullWidth = false,
    this.navigateToVendor = true, // Default to true for Discovery
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final habitItems = cart.items.where((item) => item.product.id == product.id && item.isHabit).toList();
    final todayItems = cart.items.where((item) => item.product.id == product.id && !item.isHabit).toList();
    
    final habitQuantity = habitItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final todayQuantity = todayItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalQuantity = habitQuantity + todayQuantity;
    
    final isServiceable = vendor.isServiceable ?? true;

    return IgnorePointer(
      ignoring: !isServiceable,
      child: Opacity(
        opacity: isServiceable ? 1.0 : 0.6,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: totalQuantity == 0
              ? _buildAddButton(context, ref, cart, isServiceable)
              : _buildSelector(ref, habitQuantity, todayQuantity, isServiceable),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, CartState cart, bool isServiceable) {
    return SizedBox(
      key: const ValueKey('add_button'),
      width: isFullWidth ? double.infinity : 100, // 🎯 Scale to layout
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
            final currentGoal = ref.read(homeFilterProvider);
            HabitSelectionDrawer.show(
              context, 
              vendor, 
              product, 
              currentGoal, 
              navigateToVendor: navigateToVendor // 🎯 Pass the directive
            );
          }
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isServiceable ? AppColors.brandGreenLight : Colors.white,
          foregroundColor: isServiceable ? AppColors.brandGreen : Colors.grey,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isServiceable ? AppColors.brandGreen.withValues(alpha: 0.5) : Colors.grey[300]!, width: 1.2),
          ),
        ),
        child: Text(
          isServiceable ? 'ADD' : 'UNAVAILABLE',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.8),
        ),
      ),
    );
  }

  Widget _buildSelector(WidgetRef ref, int habitQty, int todayQty, bool isServiceable) {
    final totalQty = habitQty + todayQty;
    final isMixed = habitQty > 0 && todayQty > 0;
    
    // Use Teal for habits, Green for today
    final primaryColor = (habitQty > 0) ? const Color(0xFF008080) : AppColors.brandGreen;
    final secondaryColor = (habitQty > 0) ? const Color(0xFFE0F2F1) : AppColors.brandGreen.withOpacity(0.05);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (habitQty > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "MISSION 5-DAY",
                style: GoogleFonts.poppins(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
        else if (todayQty > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "JUST TODAY",
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: AppColors.brandGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
        Container(
          key: const ValueKey('quantity_selector'),
          width: isFullWidth ? double.infinity : 100, // 🎯 Scale to layout
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight, // Sync with ADD button bg
            borderRadius: BorderRadius.circular(12), // Match ADD button radius
            border: Border.all(color: isServiceable ? AppColors.brandGreen.withValues(alpha: 0.5) : Colors.grey[300]!, width: 1.2), // Sharper border
            boxShadow: [
              if (isServiceable)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: Icons.remove,
                color: isServiceable ? primaryColor : Colors.grey,
                onTap: isServiceable ? () {
                  // Decrement logic: Priorities today first, then habit
                  if (todayQty > 0) {
                    ref.read(cartProvider.notifier).updateQuantity(product.id, todayQty - 1, isHabit: false);
                  } else {
                    ref.read(cartProvider.notifier).updateQuantity(product.id, habitQty - 1, isHabit: true);
                  }
                } : null,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$totalQty',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isServiceable ? primaryColor : Colors.grey,
                      height: 1,
                    ),
                  ),
                  if (isMixed)
                    Text(
                      '(${habitQty}H+${todayQty}T)',
                      style: TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: primaryColor.withOpacity(0.8)),
                    ),
                ],
              ),
              _buildActionButton(
                icon: Icons.add,
                color: isServiceable ? primaryColor : Colors.grey,
                onTap: isServiceable ? () {
                  // Increment logic: Priorities habit if in habit mode
                  if (habitQty > 0) {
                    ref.read(cartProvider.notifier).updateQuantity(product.id, habitQty + 1, isHabit: true);
                  } else {
                    ref.read(cartProvider.notifier).updateQuantity(product.id, todayQty + 1, isHabit: false);
                  }
                } : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}
