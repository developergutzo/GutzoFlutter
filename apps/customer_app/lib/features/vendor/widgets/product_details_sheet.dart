import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_core/services/cart_service.dart';
import '../../../widgets/habit_selection_drawer.dart';
import '../../home/home_screen.dart';

class ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;
  final Vendor vendor;

  const ProductDetailsSheet({super.key, required this.product, required this.vendor});

  static Future<void> show(BuildContext context, Product product, Vendor vendor) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailsSheet(product: product, vendor: vendor),
    );
  }

  @override
  ConsumerState<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<ProductDetailsSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Product Image
          if (widget.product.image.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.product.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DietaryBadge(dietaryType: widget.product.dietaryType, size: 14),
                          const SizedBox(height: 4),
                          Text(
                            widget.product.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${widget.product.price}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brandGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.product.description,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSub, height: 1.5),
                ),
                
                const SizedBox(height: 24),
                if (widget.product.nutritionalInfo != null) ...[
                  _buildNutritionStrip(widget.product.nutritionalInfo!),
                  const SizedBox(height: 24),
                ],
                const Divider(),
                const SizedBox(height: 12),
                
                // Variants placeholder
                const Text('Customize', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Regular Size', style: TextStyle(color: AppColors.textMain)),
                
                const SizedBox(height: 24),
                
                // High-Conversion ADD Button
                SizedBox(
                  width: double.infinity,
                  height: 56, // BIG SIZE for primary revenue intent
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close details
                      final currentFilter = ref.read(homeFilterProvider);
                      // Mandate intent choice via the HabitSelectionDrawer
                      HabitSelectionDrawer.show(
                        context, 
                        widget.vendor, 
                        widget.product, 
                        currentFilter
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreenLight, // Secondary Green Bg
                      foregroundColor: AppColors.brandGreen, // Primary Green Text
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.brandGreen.withValues(alpha: 0.5), width: 1.2), // Sharper border for better CTA
                      ),
                    ),
                    child: Text(
                      'ADD • ₹${widget.product.price}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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

  Widget _buildNutritionStrip(Map<String, dynamic> nutrition) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionItem('Calories', '${nutrition['calories'] ?? 0}', 'kcal', Icons.bolt, Colors.orange),
              _buildNutritionItem('Protein', '${nutrition['protein'] ?? 0}g', '💪', Icons.fitness_center, Colors.blue),
              _buildNutritionItem('Carbs', '${nutrition['carbs'] ?? 0}g', '🌾', Icons.grain, Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionItem('Fats', '${nutrition['fat'] ?? 0}g', '💧', Icons.water_drop, Colors.red),
              _buildNutritionItem('Fiber', '${nutrition['fiber'] ?? 0}g', '🌿', Icons.grass, Colors.green),
              _buildNutritionItem('Sugar', '${nutrition['sugar'] ?? 0}g', '🚫', Icons.block, Colors.pink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textMain),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textDisabled, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
