import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';
import '../features/vendor/vendor_detail_screen.dart';

class VendorCard extends StatefulWidget {
  final Map<String, dynamic>? rawVendor;
  final String imageUrl;
  final String title;
  final String cuisine;
  final String deliveryTime;
  final double rating;
  final Vendor? vendorModel;
  final String? searchQuery;

  const VendorCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.cuisine,
    required this.deliveryTime,
    required this.rating,
    this.vendorModel,
    this.rawVendor,
    this.searchQuery,
  });

  @override
  State<VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<VendorCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered && isWeb ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: () {
            if (widget.vendorModel != null) {
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
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered && isWeb ? AppColors.brandGreen : AppColors.border.withValues(alpha: 0.4),
                width: _isHovered && isWeb ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered && isWeb 
                    ? AppColors.brandGreen.withValues(alpha: 0.08) 
                    : Colors.black.withValues(alpha: 0.03),
                  blurRadius: _isHovered && isWeb ? 40 : 15,
                  offset: Offset(0, _isHovered && isWeb ? 15 : 4),
                )
              ],
            ),
            child: Opacity(
              opacity: widget.vendorModel?.isServiceable == false ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with Badge
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ColorFiltered(
                          colorFilter: widget.vendorModel?.isServiceable == false
                              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: Hero(
                            tag: 'vendor_${widget.vendorModel?.id ?? widget.title}',
                            child: Image.network(
                              (widget.vendorModel?.products != null && widget.vendorModel!.products!.isNotEmpty)
                                  ? widget.vendorModel!.products!.first.displayImage
                                  : (widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c'),
                              height: context.isMobile ? 220 : 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 180,
                                color: AppColors.shimmerBase,
                                child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textDisabled),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.vendorModel?.isServiceable == false)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Text(
                                'Currently Unserviceable',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                
                // Primary Title: Dish Name or Vendor Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.vendorModel?.products != null && widget.vendorModel!.products!.isNotEmpty)
                                ? widget.vendorModel!.products!.first.name
                                : widget.title,
                            style: TextStyle(
                              fontSize: context.isMobile ? 20 : 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMain,
                              letterSpacing: -0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${widget.title} • ${widget.deliveryTime.isNotEmpty ? widget.deliveryTime : "25-35 mins"}',
                            style: const TextStyle(
                              color: AppColors.textSub,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Revenue Button: + ADD
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange[700], // Brand action color
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Text(
                        '+ ADD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                // Status Row (Rating • Cuisine)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.brandGreen, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      (widget.rating == 0.0 ? 4.5 : widget.rating).toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.cuisine.isNotEmpty ? widget.cuisine : 'Multi-cuisine',
                        style: const TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.trim().isEmpty) return "Coimbatore";
    final parts = address.split(',').map((p) => p.trim()).toList();
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return address;
  }
}
