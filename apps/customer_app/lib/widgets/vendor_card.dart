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

  const VendorCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.cuisine,
    required this.deliveryTime,
    required this.rating,
    this.vendorModel,
    this.rawVendor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (vendorModel != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorDetailScreen(vendor: vendorModel!),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF43A047), size: 18),
                const SizedBox(width: 4),
                Text(
                  (rating == 0.0 ? 4.5 : rating).toString(),
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  deliveryTime,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (vendorModel?.tags != null && vendorModel!.tags!.isNotEmpty)
              Text(
                vendorModel!.tags!.join(', '),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              vendorModel?.location ?? '',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
