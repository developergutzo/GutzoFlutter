import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  void _showHabitDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
            Text(
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
                "Most people choosing Muscle Gain pick the 5-Day Pack.",
                style: TextStyle(
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
              isSelected: false,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            _buildOption(
              title: "5-Day Habit Pack",
              subtitle: "Lock in your progress & Save ₹150",
              price: "₹1199",
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
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

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;
    final mealName = (widget.vendorModel?.products != null && widget.vendorModel!.products!.isNotEmpty)
        ? widget.vendorModel!.products!.first.name
        : widget.title;

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
          borderRadius: BorderRadius.circular(20),
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
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: _buildImage((widget.vendorModel?.products != null && widget.vendorModel!.products!.isNotEmpty)
                          ? widget.vendorModel!.products!.first.displayImage
                          : (widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg'),
                          context),
                    ),
                    // Trust Pill: Top Right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            Text(
                              " ${(widget.rating == 0.0 ? 4.5 : widget.rating).toStringAsFixed(1)}",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                            const Text(' | ', style: TextStyle(color: Colors.black26, fontSize: 10)),
                            Text(
                              widget.deliveryTime.isNotEmpty ? widget.deliveryTime.split(' ').first : '25',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                            const Text(' MINS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.black54)),
                          ],
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${widget.title}',
                        style: const TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "₹299",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          InkWell(
                            onTap: () => _showHabitDrawer(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '+ ADD',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
