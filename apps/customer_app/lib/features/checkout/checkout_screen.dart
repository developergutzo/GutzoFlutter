import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/models/address.dart';
import 'package:shared_core/services/auth_service.dart';
import '../orders/order_tracking_screen.dart';
import '../../widgets/quantity_selector.dart';
import '../vendor/vendor_detail_screen.dart';
import '../auth/auth_screen.dart';
import 'checkout_notifier.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';
import 'package:shared_core/services/location_service.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);
    final location = ref.watch(locationProvider);
    
    // Automatically pop screen if last item is deleted to match gutzo.in UX
    ref.listen(cartProvider, (previous, next) {
      if (next.items.isEmpty && (previous?.items.isNotEmpty ?? false)) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    if (cart.items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    final vendor = cart.items.first.vendor;
    final isWeb = context.isDesktop || context.isTablet;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: isWeb ? _buildWebAppBar(context, vendor, checkout, location) : _buildMobileAppBar(context, vendor, checkout, location),
      body: isWeb 
          ? _buildWebLayout(context, ref, cart, checkout, vendor, location)
          : _buildMobileLayout(context, ref, cart, checkout, vendor, location),
      bottomSheet: isWeb ? null : _buildPayFooter(context, ref, cart, checkout),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, Vendor vendor, CheckoutState checkout, LocationState location) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendor.name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Text(
                checkout.eta ?? 'Pending...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                ' to ${checkout.selectedAddress?.city ?? location.location?.city ?? 'Location'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildWebAppBar(BuildContext context, Vendor vendor, CheckoutState checkout, LocationState location) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${checkout.eta ?? 'Pending...'} • to ${checkout.selectedAddress?.city ?? location.location?.city ?? 'Location'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, CartState cart, CheckoutState checkout, Vendor vendor, LocationState location) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildItemsSection(context, ref, cart, checkout, vendor),
          const SizedBox(height: 12),
          _buildBillingSection(cart, checkout, location),
          const SizedBox(height: 12),
          _buildCancellationPolicy(),
          const SizedBox(height: 12),
          _buildDevSettings(context, ref, checkout),
          const SizedBox(height: 100), // Space for footer
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context, WidgetRef ref, CartState cart, CheckoutState checkout, Vendor vendor, LocationState location) {
    return SingleChildScrollView(
      child: MaxWidthContainer(
        padding: const EdgeInsets.only(top: 40, bottom: 100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Items & Instructions)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildItemsSection(context, ref, cart, checkout, vendor),
                  const SizedBox(height: 24),
                  _buildCancellationPolicy(),
                  const SizedBox(height: 24),
                  _buildDevSettings(context, ref, checkout),
                ],
              ),
            ),
            const SizedBox(width: 40),
            // Right Column (Billing & Pay) - Sticky-like
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildWebBillingSidebar(context, ref, cart, checkout, location),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context, WidgetRef ref, CartState cart, CheckoutState checkout, Vendor vendor) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...cart.items.map((item) => _buildCartItem(item)),
          const SizedBox(height: 24),
          _buildAddMoreButton(context, vendor),
          const SizedBox(height: 24),
          _buildActionButtons(context, ref, checkout),
        ],
      ),
    );
  }

  Widget _buildBillingSection(CartState cart, CheckoutState checkout, LocationState location) {
    return _buildSectionCard(
      child: Column(
        children: [
          if (!checkout.isServiceable) _buildServiceabilityWarning(),
          _BillingSummary(
            subtotal: cart.subtotal,
            originalSubtotal: cart.originalSubtotal,
            deliveryFee: checkout.useFreeFees ? 0 : checkout.deliveryFee,
            platformFee: checkout.useFreeFees ? 0 : checkout.platformFee,
            packagingFee: checkout.packagingFee,
            gst: checkout.gst,
            donationAmount: checkout.isDonationChecked ? checkout.donationAmount : 0,
            isCalculatingFee: checkout.isCheckingServiceability,
            hasAddress: checkout.selectedAddress != null || location.location != null,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceabilityWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEB2B2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC53030), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Not Serviceable',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC53030),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We are sorry, but our delivery partners do not serve this specific location yet. Please try a different address.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9B2C2C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebBillingSidebar(BuildContext context, WidgetRef ref, CartState cart, CheckoutState checkout, LocationState location) {
    final total = cart.subtotal + 
                (checkout.useFreeFees ? 0 : checkout.deliveryFee) + 
                (checkout.useFreeFees ? 0 : checkout.platformFee) + 
                checkout.packagingFee +
                // checkout.gst + // GST is now inclusive
                (checkout.isDonationChecked ? checkout.donationAmount : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 32),
          _BillingSummary(
            subtotal: cart.subtotal,
            originalSubtotal: cart.originalSubtotal,
            deliveryFee: checkout.useFreeFees ? 0 : checkout.deliveryFee,
            platformFee: checkout.useFreeFees ? 0 : checkout.platformFee,
            packagingFee: checkout.packagingFee,
            gst: checkout.gst,
            donationAmount: checkout.isDonationChecked ? checkout.donationAmount : 0,
            isInitiallyExpanded: true,
            isCalculatingFee: checkout.isCheckingServiceability,
            hasAddress: checkout.selectedAddress != null || location.location != null,
          ),
          const SizedBox(height: 24),
          if (!checkout.isServiceable) _buildServiceabilityWarning(),
          const SizedBox(height: 40),
          _buildPayButton(context, ref, checkout, total),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_sharp, color: AppColors.brandGreen, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Safe & Secure Payments',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDisabled, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(BuildContext context, WidgetRef ref, CheckoutState checkout, double total) {
    final user = ref.watch(currentUserProvider);
    final isDisabled = checkout.isProcessing || !checkout.isServiceable || checkout.isCheckingServiceability;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: isDisabled ? null : () async {
          if (user == null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
            return;
          }
          final result = await ref.read(checkoutProvider.notifier).placeOrder();
          if (result != null && result.length > 30 && !result.contains(' ')) { 
             Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: result)),
             );
          } else if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result), backgroundColor: Colors.redAccent));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: (checkout.isServiceable && !checkout.isCheckingServiceability) ? AppColors.brandGreen : Colors.grey[400],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: checkout.isProcessing 
          ? const CircularProgressIndicator(color: Colors.white)
          : checkout.isCheckingServiceability
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Calculating Total...', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              )
            : Text(
              user == null 
                  ? 'Login to Pay' 
                  : (checkout.isServiceable 
                      ? 'Confirm Order • ₹${total.toStringAsFixed(2)}' 
                      : 'Not Serviceable'),
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.product.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${item.product.price}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          QuantitySelector(product: item.product, vendor: item.vendor),
        ],
      ),
    );
  }

  Widget _buildAddMoreButton(BuildContext context, Vendor vendor) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Add more items',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, CheckoutState state) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallActionButton(
            icon: Icons.description_outlined,
            label: state.orderNote.isEmpty ? 'Add a note' : 'Note: ${state.orderNote}',
            onTap: () => _showNoteBottomSheet(context, ref, state.orderNote),
            isActive: state.orderNote.isNotEmpty,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallActionButton(
            icon: Icons.flatware_outlined,
            label: state.dontAddCutlery ? "Don't add cutlery" : "Don't add...",
            onTap: () => ref.read(checkoutProvider.notifier).toggleCutlery(),
            isActive: state.dontAddCutlery,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? AppColors.brandGreen : Colors.grey[600];
    final bgColor = isActive ? AppColors.brandGreen.withValues(alpha: 0.05) : Colors.transparent;
    final borderColor = isActive ? AppColors.brandGreen : Colors.grey[200]!;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.brandGreen : Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationPolicy() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CANCELLATION POLICY',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders cannot be cancelled once placed. No refunds will be provided. Please review your order carefully before confirming.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevSettings(BuildContext context, WidgetRef ref, CheckoutState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50], // Very subtle background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Environment (Dev Only)'.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.devEnvironment,
                isExpanded: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                items: const [
                  DropdownMenuItem(value: 'full_mock', child: Text('Full Mock (Mock Pay, Mock Del)')),
                  DropdownMenuItem(value: 'real_pay_mock_del', child: Text('Real Payment, Mock Delivery')),
                  DropdownMenuItem(value: 'mock_pay_real_del', child: Text('Mock Payment, Real Delivery')),
                  DropdownMenuItem(value: 'production', child: Text('Full Production (Real Pay/Del)')),
                ],
                onChanged: (val) => ref.read(checkoutProvider.notifier).setDevEnvironment(val!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => ref.read(checkoutProvider.notifier).setUseFreeFees(!state.useFreeFees),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: state.useFreeFees,
                    activeColor: AppColors.brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => ref.read(checkoutProvider.notifier).setUseFreeFees(val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Free Delivery & Platform Fee',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayFooter(BuildContext context, WidgetRef ref, CartState cart, CheckoutState checkout) {
    final user = ref.watch(currentUserProvider);
    final total = cart.subtotal + 
                (checkout.useFreeFees ? 0 : checkout.deliveryFee) + 
                (checkout.useFreeFees ? 0 : checkout.platformFee) + 
                checkout.packagingFee +
                // checkout.gst + // GST is now inclusive
                (checkout.isDonationChecked ? checkout.donationAmount : 0);

    final savings = cart.originalSubtotal - cart.subtotal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (savings > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F1),
              border: Border(bottom: BorderSide(color: Color(0xFFCDEBDD))),
            ),
            child: Text(
              '🎉 ₹${savings.toStringAsFixed(0)} savings applied! Complete order to keep this discount.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brandGreen,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: savings > 0 ? Radius.zero : const Radius.circular(24),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
            ],
          ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user == null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Continue with WhatsApp number',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              )
            else
              ElevatedButton(
                onPressed: (checkout.isProcessing || !checkout.isServiceable || checkout.isCheckingServiceability) ? null : () async {
                  final result = await ref.read(checkoutProvider.notifier).placeOrder();
                  // Check if result is a valid UUID (usually 36 chars) or at least not an error message
                  if (result != null && result.length > 30 && !result.contains(' ')) { 
                     // Track Order
                     if (context.mounted) {
                       Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => OrderTrackingScreen(orderId: result)),
                       );
                     }
                  } else if (result != null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (checkout.isServiceable && !checkout.isCheckingServiceability) ? AppColors.brandGreen : Colors.grey[400],
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: checkout.isProcessing 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : checkout.isCheckingServiceability
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text('Calculating Total...', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      )
                    : Text(
                        checkout.isServiceable ? 'Pay ₹${total.toStringAsFixed(2)}' : 'Location Not Serviceable',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            const SizedBox(height: 12),
            Text(
              '100% Secure Payments',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  ],
);
  }

  void _showNoteBottomSheet(BuildContext context, WidgetRef ref, String initialNote) {
    final controller = TextEditingController(text: initialNote);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a note',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Any special instructions...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(checkoutProvider.notifier).setOrderNote(controller.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Save Note', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingSummary extends StatefulWidget {
  final double subtotal;
  final double originalSubtotal;
  final double deliveryFee;
  final double platformFee;
  final double packagingFee;
  final double gst;
  final double donationAmount;
  final bool isInitiallyExpanded;
  final bool isCalculatingFee;
  final bool hasAddress;

  const _BillingSummary({
    required this.subtotal,
    required this.originalSubtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.packagingFee,
    required this.gst,
    this.donationAmount = 0,
    this.isInitiallyExpanded = false,
    this.isCalculatingFee = false,
    this.hasAddress = true,
  });

  @override
  State<_BillingSummary> createState() => _BillingSummaryState();
}

class _BillingSummaryState extends State<_BillingSummary> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final savings = widget.originalSubtotal - widget.subtotal;
    final total = widget.subtotal + 
                  widget.deliveryFee + 
                  widget.platformFee + 
                  widget.packagingFee +
                  // widget.gst + // GST is now inclusive
                  widget.donationAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined, size: 20, color: Colors.grey[700]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total Bill',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.isCalculatingFee)
                          Text(
                            'Calculating...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[400],
                            ),
                          )
                        else ...[
                          if (savings > 0)
                            Text(
                              '₹${(total + savings).toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[400],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (savings > 0 && !widget.isCalculatingFee)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'You saved ₹${savings.toStringAsFixed(0)} on this order!',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 16),
          _buildBillRow('Item Total', widget.subtotal),
          if (savings > 0)
            _buildBillRow('Gutzo Savings', -savings, isDiscount: true),
          if (widget.isCalculatingFee)
            _buildCalculatingRow('Delivery Partner Fee')
          else if (!widget.hasAddress)
            _buildActionRow('Delivery Partner Fee', 'Enter Address')
          else
            _buildBillRow('Delivery Partner Fee', widget.deliveryFee),
          _buildBillRow('Platform Fee', widget.platformFee),
          if (widget.packagingFee > 0)
            _buildBillRow('Packaging Fee', widget.packagingFee),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F4)),
          ),
          
          if (widget.isCalculatingFee)
            _buildCalculatingRow('Total Payable', isBold: true)
          else
            _buildBillRow('Total Payable', total, isBold: true),
          
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Includes ₹${widget.gst.toStringAsFixed(2)} GST and Restaurant Charges',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),

          if (widget.donationAmount > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow('Feeding India Donation', widget.donationAmount),
          ],
        ],
      ],
    );
  }

  /// Row shown when an action is required (e.g. "Enter Address")
  Widget _buildActionRow(String label, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: GoogleFonts.poppins(
              fontSize: 13, 
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            )
          ),
          Text(
            action, 
            style: GoogleFonts.poppins(
              fontSize: 13, 
              color: AppColors.brandGreen, 
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, double value, {bool isDiscount = false, bool isBold = false}) {
    final isFree = value == 0 && !isDiscount && !isBold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: GoogleFonts.poppins(
              fontSize: 13, 
              color: isBold ? Colors.black : Colors.grey[600],
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            )
          ),
          Text(
            isFree ? 'FREE' : '${isDiscount ? '-' : ''}₹${value.abs().toStringAsFixed(2)}', 
            style: GoogleFonts.poppins(
              fontSize: 13, 
              color: isDiscount || isFree ? AppColors.brandGreen : (isBold ? Colors.black : Colors.grey[800]), 
              fontWeight: (isBold || isDiscount || isFree) ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Shimmer row shown while Shadowfax serviceability API is in-flight
  Widget _buildCalculatingRow(String label, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isBold ? Colors.black : Colors.grey[600],
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            'Calculating...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
