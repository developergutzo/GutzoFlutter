import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../../widgets/cart_strip.dart';
import 'widgets/product_details_sheet.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  late Future<List<Product>> _productsFuture;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
  }

  Future<List<Product>> _loadProducts() async {
    try {
      final response = await ref.read(nodeApiServiceProvider).getVendorProducts(widget.vendor.id);
      List<dynamic> productList = [];
      if (response is List) {
        productList = response;
      } else if (response is Map && response['data'] is List) {
        productList = response['data'];
      }
      return productList.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      return widget.vendor.products ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          final categories = ['All', ...products.map((p) => p.category).toSet()];
          
          final filteredProducts = _selectedCategory == 'All' 
              ? products 
              : products.where((p) => p.category == _selectedCategory).toList();

          return CustomScrollView(
            slivers: [
              // Hero AppBar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.vendor.image.isNotEmpty ? widget.vendor.image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vendor.name,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.vendor.cuisineType,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Vendor Info Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _infoChip(Icons.star, widget.vendor.rating.toString(), Colors.amber),
                      const SizedBox(width: 12),
                      _infoChip(Icons.timer_outlined, widget.vendor.deliveryTime, Colors.blue),
                      const SizedBox(width: 12),
                      _infoChip(Icons.location_on_outlined, '2.4 km', AppColors.brandGreen),
                    ],
                  ),
                ),
              ),

              // Sticky Categories
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryHeaderDelegate(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (cat) {
                    setState(() => _selectedCategory = cat);
                  },
                ),
              ),

              // Product List
              snapshot.connectionState == ConnectionState.waiting
                  ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _productCard(filteredProducts[index]),
                          childCount: filteredProducts.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
      bottomNavigationBar: const SafeArea(child: CartStrip()),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _productCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: product.isVeg ? Colors.green : Colors.red, size: 12),
                const SizedBox(height: 4),
                Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                ),
                const SizedBox(height: 8),
                Text('₹${product.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.image.isNotEmpty ? product.image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: -10,
                left: 10,
                right: 10,
                child: ElevatedButton(
                  onPressed: () {
                    ProductDetailsSheet.show(context, product, widget.vendor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandGreen,
                    elevation: 4,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(80, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) => onCategorySelected(cat),
              selectedColor: AppColors.brandGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) => true;
}
