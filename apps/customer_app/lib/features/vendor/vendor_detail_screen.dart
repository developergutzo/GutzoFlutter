import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/vendor.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/node_api_service.dart';
import '../../widgets/cart_strip.dart';
import '../../widgets/quantity_selector.dart';
import 'widgets/product_details_sheet.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  final Vendor vendor;
  final String? searchQuery;

  const VendorDetailScreen({super.key, required this.vendor, this.searchQuery});

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  late Future<List<Product>> _productsFuture;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.searchQuery != null ? 'Best Matches' : 'All';
    _productsFuture = _loadProducts();
  }

  Future<List<Product>> _loadProducts() async {
    try {
      final response = await ref.read(nodeApiServiceProvider).getVendorProducts(widget.vendor.id);
      debugPrint('VendorDetailScreen: Products response: $response');
      
      List<dynamic> productList = [];
      if (response is List) {
        productList = response;
      } else if (response is Map) {
        if (response['data'] is List) {
          productList = response['data'];
        } else if (response['products'] is List) {
          productList = response['products'];
        } else if (response['data'] is Map && response['data']['products'] is List) {
          productList = response['data']['products'];
        }
      }
      
      final products = productList.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
      debugPrint('VendorDetailScreen: Parsed ${products.length} products');
      return products;
    } catch (e, stack) {
      debugPrint('VendorDetailScreen: Error loading products: $e');
      debugPrint('Stack trace: $stack');
      return widget.vendor.products ?? [];
    }
  }

  String _formatAddress(String address) {
    if (address.trim().isEmpty) return "Coimbatore";
    final parts = address.split(',').map((p) => p.trim()).toList();
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return address;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          final query = widget.searchQuery?.trim().toLowerCase();
          
          // Identify matching products for the virtual "Best Matches" category
          final matchingProducts = query != null && query.isNotEmpty
              ? products.where((p) {
                  return p.name.toLowerCase().contains(query) || 
                         p.description.toLowerCase().contains(query) ||
                         (p.tags?.any((t) => t.toLowerCase().contains(query)) ?? false);
                }).toList()
              : <Product>[];

          // Normalize categories
          final categorySet = products.map((p) => p.category.trim()).where((c) => c.isNotEmpty).toSet();
          final List<String> categories = [];
          
          if (matchingProducts.isNotEmpty) {
            categories.add('Best Matches');
          }
          categories.add('All');
          categories.addAll(categorySet.toList()..sort());
          
          // Ensure _selectedCategory is valid if data just loaded
          if (!categories.contains(_selectedCategory)) {
             _selectedCategory = categories.first;
          }

          final List<Product> filteredProducts;
          if (_selectedCategory == 'Best Matches') {
            filteredProducts = matchingProducts;
          } else if (_selectedCategory == 'All') {
            filteredProducts = products;
          } else {
            filteredProducts = products.where((p) => p.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase()).toList();
          }

          return CustomScrollView(
            slivers: [
              // Clean Text Header
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.textMain, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.ios_share, color: AppColors.textMain, size: 24),
                    onPressed: () {},
                  ),
                ],
              ),

              // Vendor Title & Info Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Floating Info Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${widget.vendor.cuisineType} · Healthy",
                                        style: GoogleFonts.poppins(
                                          color: AppColors.brandGreen,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandGreen,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.white, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.vendor.rating.toStringAsFixed(1),
                                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.vendor.deliveryTime.trim().isNotEmpty ? widget.vendor.deliveryTime : "40-45 mins",
                                    style: const TextStyle(
                                      color: AppColors.textMain,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textDisabled),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatAddress(widget.vendor.location),
                                        style: const TextStyle(
                                          color: AppColors.textDisabled,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Offer Strip
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFEFEB),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.moped_outlined, color: Color(0xFFE64A19), size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Placeholder for offer details.",
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFE64A19),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Pick Your Food",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Sticky Categories (Hidden to match reference design until further notice)
              // SliverPersistentHeader(
              //   pinned: true,
              //   delegate: _CategoryHeaderDelegate(
              //     categories: categories,
              //     selectedCategory: _selectedCategory,
              //     onCategorySelected: (cat) {
              //       setState(() => _selectedCategory = cat);
              //     },
              //   ),
              // ),

              // Product List
              snapshot.connectionState == ConnectionState.waiting
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
                    )
                  : filteredProducts.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No products found in this category',
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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


  Widget _productCard(Product product) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: product.isVeg ? AppColors.brandGreen : Colors.red, size: 12),
                const SizedBox(height: 8),
                _highlightedText(
                  product.name, 
                  widget.searchQuery, 
                  GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain, letterSpacing: -0.1)
                ),
                const SizedBox(height: 4),
                // Price Row
                Row(
                  children: [
                    Text(
                      '₹${(product.price * 1.2).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textDisabled,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Rating
                if (product.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.brandGreen, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${product.rating} (${product.ratingCount ?? 0})",
                        style: GoogleFonts.poppins(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                _highlightedText(
                  product.description,
                  widget.searchQuery,
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub, height: 1.4),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Side: Image and Add Button
          SizedBox(
            width: 120,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: product.displayImage.toLowerCase().endsWith('.svg')
                      ? SvgPicture.network(
                          product.displayImage,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          product.displayImage,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 110,
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.restaurant, color: Colors.grey),
                          ),
                        ),
                  ),
                ),
                Positioned(
                  bottom: -15,
                  child: QuantitySelector(product: product, vendor: widget.vendor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightedText(String text, String? query, TextStyle baseStyle, {int? maxLines}) {
    if (query == null || query.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    int matchIndex = textLower.indexOf(queryLower);
    while (matchIndex != -1) {
      if (matchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, matchIndex)));
      }
      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + query.length),
        style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.w900, backgroundColor: Color(0xFFE6F4EA)),
      ));
      start = matchIndex + query.length;
      matchIndex = textLower.indexOf(queryLower, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(children: spans, style: baseStyle),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
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
      color: Colors.white,
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
