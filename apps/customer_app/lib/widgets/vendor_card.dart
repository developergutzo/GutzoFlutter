import 'package:flutter/material.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../features/vendor/vendor_detail_screen.dart';

class VendorCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (vendorModel != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorDetailScreen(
                vendor: vendorModel!,
                searchQuery: searchQuery,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 190,
                    color: AppColors.shimmerBase,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textDisabled),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title Row
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // Status Row (Rating • Serviceable)
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.brandGreen, size: 16),
              const SizedBox(width: 4),
              Text(
                (rating == 0.0 ? 4.5 : rating).toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: AppColors.textDisabled, fontSize: 14)),
              const SizedBox(width: 8),
              if (vendorModel?.isServiceable == false)
                const Text(
                  'Not Serviceable',
                  style: TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                const Text(
                  'Serviceable',
                  style: TextStyle(
                    color: AppColors.brandGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Cuisine section
          Text(
            cuisine.isNotEmpty ? cuisine : 'Multi-cuisine',
            style: const TextStyle(
              color: AppColors.textSub,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // Location
          if (vendorModel?.location != null && vendorModel!.location.isNotEmpty)
            Text(
              vendorModel!.location,
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
