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
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';

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
    _selectedCategory = 'All';
    _productsFuture = _loadProducts();
  }

  Future<List<Product>> _loadProducts() async {
    try {
      debugPrint('VendorDetailScreen: Fetching products for vendor ${widget.vendor.id}...');
      final response = await ref.read(nodeApiServiceProvider).getVendorProducts(widget.vendor.id);
      
      List<dynamic> productList = [];
      if (response is List) {
        productList = response;
      } else if (response is Map) {
        if (response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            productList = data;
          } else if (data is Map && data['products'] is List) {
            productList = data['products'];
          }
        } else if (response['products'] is List) {
          productList = response['products'];
        }
      }
      
      final products = productList.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
      debugPrint('VendorDetailScreen: Successfully loaded ${products.length} products');
      
      // If API returns empty but we have local backup, use that as last resort
      if (products.isEmpty && widget.vendor.products != null && widget.vendor.products!.isNotEmpty) {
        return widget.vendor.products!;
      }
      
      return products;
    } catch (e, stack) {
      debugPrint('VendorDetailScreen: Error loading products: $e');
      debugPrint('Stack trace: $stack');
      // Fallback to local products if API fails
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
    return FutureBuilder<List<Product>>(
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
        final categorySet = products
            .map((p) => p.category.trim())
            .where((c) => c.isNotEmpty)
            .toSet();
            
        final List<String> categories = ['All'];
        
        final sortedCategories = categorySet.toList()..sort();
        categories.addAll(sortedCategories);
        
        // Identify effective category (don't modify state in build!)
        String effectiveCategory = _selectedCategory;
        if (!categories.contains(effectiveCategory)) {
           effectiveCategory = categories.contains('All') ? 'All' : (categories.isNotEmpty ? categories.first : 'All');
        }

        final List<Product> filteredProducts;
        if (effectiveCategory == 'All') {
          filteredProducts = products;
        } else {
          filteredProducts = products.where((p) => p.category.trim().toLowerCase() == effectiveCategory.trim().toLowerCase()).toList();
        }

        final isWeb = context.isDesktop || context.isTablet;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned.fill(
                child: isWeb 
                  ? _buildWebLayout(context, products, categories, effectiveCategory, filteredProducts)
                  : _buildMobileLayout(context, products, categories, effectiveCategory, filteredProducts),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CartStrip(isPremium: false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<Product> products, List<String> categories, String effectiveCategory, List<Product> filteredProducts) {
    return MaxWidthContainer(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0, // Disable Material 3 shadow/line on scroll
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildVendorHeaderInfo(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeaderDelegate(
              categories: categories,
              selectedCategory: effectiveCategory,
              onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
            ),
          ),
          filteredProducts.isEmpty
              ? _buildEmptyProductsView()
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
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context, List<Product> products, List<String> categories, String effectiveCategory, List<Product> filteredProducts) {
    return Column(
      children: [
        // Web Header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.transparent, width: 0)), // Ensure no grey line
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Text(
                widget.vendor.name,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.search, color: AppColors.textDisabled),
              const SizedBox(width: 24),
              const Icon(Icons.ios_share, color: AppColors.textDisabled),
            ],
          ),
        ),
        Expanded(
          child: MaxWidthContainer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Vendor Info (Sticky-like)
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVendorHeaderInfo(),
                        const SizedBox(height: 48),
                        Text(
                          "CATEGORIES",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textDisabled,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...categories.map((cat) {
                          final isSelected = cat == effectiveCategory;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.brandGreen.withValues(alpha: 0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => setState(() => _selectedCategory = cat),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Row(
                                    children: [
                                      if (isSelected)
                                        Container(
                                          width: 3,
                                          height: 16,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: AppColors.brandGreen,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          cat,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                                            letterSpacing: isSelected ? -0.2 : 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 120), // Padding for floating cart
                      ],
                    ),
                  ),
                ),
                // Right Column: Product Grid
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      filteredProducts.isEmpty
                          ? _buildEmptyProductsView()
                        : _buildWebProductGrid(filteredProducts),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)), // Padding for floating cart
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProductsView() {
    return SliverFillRemaining(
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
    );
  }

  Widget _buildVendorHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!context.isDesktop) ...[
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
        ],
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.vendor.cuisineType.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                widget.vendor.rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.timer_outlined, 
                            size: 20, 
                            color: widget.vendor.isServiceable == false ? AppColors.errorRed : AppColors.brandGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "DELIVERY TIME",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDisabled,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                widget.vendor.isServiceable == false 
                                  ? "Currently Unserviceable" 
                                  : (widget.vendor.deliveryTime.trim().isNotEmpty ? widget.vendor.deliveryTime : "40-45 mins"),
                                style: GoogleFonts.poppins(
                                  color: widget.vendor.isServiceable == false ? AppColors.errorRed : AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.textDisabled),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "LOCATION",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDisabled,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                widget.vendor.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: AppColors.textSub,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, color: AppColors.brandGreen, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Free delivery above ₹499",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppColors.brandGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebProductGrid(List<Product> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360, // Targeting 3 columns on standard desktop
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          mainAxisExtent: 220, // Significantly more compact
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _WebProductCard(product: products[index], vendor: widget.vendor),
          childCount: products.length,
        ),
      ),
    );
  }



  Widget _productCard(Product product) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
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

class _WebProductCard extends StatefulWidget {
  final Product product;
  final Vendor vendor;
  const _WebProductCard({required this.product, required this.vendor});

  @override
  State<_WebProductCard> createState() => _WebProductCardState();
}

class _WebProductCardState extends State<_WebProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isHovered ? AppColors.brandGreen.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: AppColors.brandGreen.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 16),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: widget.product.isVeg ? AppColors.brandGreen : AppColors.errorRed, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.product.isVeg ? AppColors.brandGreen : AppColors.errorRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.product.rating != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                widget.product.rating!.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15, // Condensed
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: GoogleFonts.poppins(
                      fontSize: 11, // Condensed
                      color: AppColors.textSub.withValues(alpha: 0.7),
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${widget.product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18, // Condensed
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${(widget.product.price * 1.2).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Hero(
                  tag: 'product_img_${widget.product.id}',
                  child: Container(
                    width: 90, // Condensed
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: widget.product.displayImage.toLowerCase().endsWith('.svg')
                          ? SvgPicture.network(
                              widget.product.displayImage,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              widget.product.displayImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFFF9FAFB),
                                child: Icon(Icons.restaurant_rounded, color: Colors.grey[300], size: 40),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 90, // Tighter button
                  height: 36,
                  child: QuantitySelector(product: widget.product, vendor: widget.vendor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

