import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/services/cart_service.dart';
import '../features/vendor/vendor_detail_screen.dart';
import '../features/home/home_screen.dart';
import 'habit_selection_drawer.dart';
import 'quantity_selector.dart';
import '../features/vendor/widgets/product_details_sheet.dart';

class VendorCard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? rawVendor;
  final String imageUrl;
  final String title;
  final String cuisine;
  final String deliveryTime;
  final double rating;
  final Vendor? vendorModel;
  final Product? displayProduct; // 🎯 NEW: Specific product to feature
  final String? searchQuery;
  final String? selectedGoal;

  const VendorCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.cuisine,
    required this.deliveryTime,
    required this.rating,
    this.vendorModel,
    this.displayProduct,
    this.rawVendor,
    this.searchQuery,
    this.selectedGoal,
  });

  @override
  ConsumerState<VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends ConsumerState<VendorCard> {
  bool _isHovered = false;

  void _showHabitDrawer(BuildContext context) {
    if (widget.vendorModel == null) return;
    
    // 🎯 Use the specific displayProduct if available, otherwise fallback to first
    final productToOrder = widget.displayProduct ?? 
                          (widget.vendorModel!.products?.isNotEmpty == true ? widget.vendorModel!.products!.first : null);
    
    if (productToOrder == null) return;
    
    final currentGoal = ref.read(homeFilterProvider);
    HabitSelectionDrawer.show(
      context, 
      widget.vendorModel!, 
      productToOrder, 
      currentGoal
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;
    
    // 🎯 Dish-First Logic: Feature the specific product requested
    final featuredName = widget.displayProduct?.name ?? 
                        (widget.vendorModel?.products?.isNotEmpty == true ? widget.vendorModel!.products!.first.name : widget.title);
    
    final featuredImage = widget.displayProduct?.displayImage ?? 
                         (widget.vendorModel?.products?.isNotEmpty == true ? widget.vendorModel!.products!.first.displayImage : widget.imageUrl);

    final featuredPrice = widget.displayProduct?.price ?? 299.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered && isWeb ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered && isWeb ? AppColors.brandGreen : AppColors.border.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎯 Discovery Zone: Image and Basic Info navigate to the Kitchen Page
              InkWell(
                onTap: () {
                  if (widget.vendorModel != null) {
                    if (widget.displayProduct != null) {
                      ProductDetailsSheet.show(
                        context, 
                        widget.displayProduct!, 
                        widget.vendorModel!
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VendorDetailScreen(
                            vendor: widget.vendorModel!,
                            searchQuery: widget.searchQuery,
                          ),
                        ),
                      );
                    }
                  }
                },
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: _buildImage(featuredImage.isNotEmpty ? featuredImage : 'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg',
                              context),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9), // Glassmorphic base
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  (widget.rating == 0.0 ? 4.5 : widget.rating).toStringAsFixed(1),
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  width: 1,
                                  height: 10,
                                  color: Colors.black.withValues(alpha: 0.1),
                                ),
                                Text(
                                  widget.deliveryTime.isNotEmpty ? widget.deliveryTime.split(' ').first : '25',
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                                Text(
                                  ' MINS',
                                  style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.black.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.displayProduct != null && widget.displayProduct!.healthGoals.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandGreen.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Text(
                                () {
                                  // 🎯 Priority 1: Use Selected Goal if it matches
                                  if (widget.selectedGoal != null && widget.selectedGoal != 'All') {
                                    final mappedValue = GoalConstants.goalMapping[widget.selectedGoal] ?? widget.selectedGoal!;
                                    if (widget.displayProduct!.healthGoals.contains(mappedValue)) {
                                      return widget.selectedGoal!.toUpperCase();
                                    }
                                  }
                                  
                                  // 🎯 Priority 2: Fallback to mapping the first goal back to UI name
                                  final firstGoal = widget.displayProduct!.healthGoals.first;
                                  final reverseMapping = GoalConstants.goalMapping.entries
                                      .firstWhere((e) => e.value == firstGoal, orElse: () => MapEntry(firstGoal, firstGoal))
                                      .key;
                                  return reverseMapping.toUpperCase();
                                }(),
                                style: GoogleFonts.poppins(
                                  fontSize: 7, 
                                  fontWeight: FontWeight.w900, 
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        if (widget.vendorModel?.isServiceable == false)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'UNSERVICEABLE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            featuredName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by ${widget.title}',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 🎯 Revenue Zone: Price and ADD button remain on the Home Screen for discovery
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 45,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "₹${featuredPrice.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: QuantitySelector(
                        product: widget.displayProduct!,
                        vendor: widget.vendorModel!,
                        isFullWidth: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url, BuildContext context) {
    final height = context.isMobile ? 140.0 : 180.0;
    final trimmedUrl = url.trim();
    if (trimmedUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        trimmedUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => Container(
          height: height,
          color: AppColors.shimmerBase,
          child: const Center(child: CircularProgressIndicator(color: AppColors.brandGreen, strokeWidth: 2)),
        ),
      );
    }
    return Image.network(
      trimmedUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: AppColors.shimmerBase,
        child: const Center(child: Icon(Icons.restaurant_outlined, color: AppColors.textDisabled, size: 32)),
      ),
    );
  }
}
