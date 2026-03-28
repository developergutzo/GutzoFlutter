import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/services/cart_service.dart';
import 'package:shared_core/theme/app_colors.dart';

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
                          Icon(Icons.circle, color: widget.product.isVeg ? Colors.green : Colors.red, size: 14),
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
                const Divider(),
                const SizedBox(height: 12),
                
                // Variants placeholder
                const Text('Customize', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Regular Size', style: TextStyle(color: AppColors.textMain)),
                
                const SizedBox(height: 24),
                
                // Quantity & Add to Cart
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            icon: const Icon(Icons.remove, size: 20),
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).addItem(
                            widget.product,
                            widget.vendor,
                            _quantity,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Add to Cart • ₹${widget.product.price * _quantity}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}
