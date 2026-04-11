import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';
import 'package:shared_core/widgets/max_width_container.dart';
import '../../widgets/vendor_card.dart';
import '../../widgets/cart_strip.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  const SearchResultsScreen({super.key, required this.initialQuery});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _focusNode.addListener(() {
      if (mounted && _focusNode.hasFocus != _isFocused) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
    
    // Initial focus request
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final vendorsAsync = ref.watch(vendorProvider);

    return Responsive(
      mobile: _buildMobileResults(context, ref, vendorsAsync, query),
      desktop: _buildWebResults(context, ref, vendorsAsync, query),
    );
  }

  Widget _buildMobileResults(BuildContext context, WidgetRef ref, AsyncValue vendorsAsync, String query) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Mobile Header
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textMain, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSearchInputField(),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResultsList(vendorsAsync, query)),
          ],
        ),
      ),
    );
  }

  Widget _buildWebResults(BuildContext context, WidgetRef ref, AsyncValue vendorsAsync, String query) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Web Header (Persistent style)
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  toolbarHeight: 80,
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  iconTheme: const IconThemeData(color: AppColors.textMain),
                  leadingWidth: 80,
                  leading: IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildSearchInputField(isWeb: true),
                  ),
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1.0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  sliver: SliverToBoxAdapter(
                    child: MaxWidthContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: 'Search results for ',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMain,
                                letterSpacing: -1,
                              ),
                              children: [
                                TextSpan(
                                  text: '"${_searchController.text}"',
                                  style: const TextStyle(color: AppColors.brandGreen),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Showing the best kitchens matching your craving',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 160),
                  sliver: SliverToBoxAdapter(
                    child: MaxWidthContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildResultsGrid(vendorsAsync, query),
                    ),
                  ),
                ),
              ],
            ),
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
  }

  Widget _buildSearchInputField({bool isWeb = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 48),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onTap: () => setState(() => _isFocused = true),
        onChanged: (val) => setState(() {}),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        decoration: InputDecoration(
          hintText: "What do you feel like today?",
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16, fontWeight: FontWeight.w400),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isWeb ? AppColors.webGlassBorder : const Color(0xFFF3F4F6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isWeb ? AppColors.webGlassBorder : const Color(0xFFF3F4F6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildResultsGrid(AsyncValue vendorsAsync, String query) {
    return vendorsAsync.when(
      data: (vendors) {
        final filtered = _filterVendors(vendors, query);
        if (filtered.isEmpty) return _buildEmptyState();
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisSpacing: 32,
            crossAxisSpacing: 32,
            childAspectRatio: 1.1,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final vendor = filtered[index];
            return VendorCard(
              imageUrl: vendor.image,
              title: vendor.name,
              cuisine: vendor.cuisineType,
              deliveryTime: vendor.deliveryTime,
              rating: vendor.rating,
              vendorModel: vendor,
              searchQuery: query,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildResultsList(AsyncValue vendorsAsync, String query) {
    return vendorsAsync.when(
      data: (vendors) {
        final filtered = _filterVendors(vendors, query);
        if (filtered.isEmpty) return _buildEmptyState();
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final vendor = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: VendorCard(
                imageUrl: vendor.image,
                title: vendor.name,
                cuisine: vendor.cuisineType,
                deliveryTime: vendor.deliveryTime,
                rating: vendor.rating,
                vendorModel: vendor,
                searchQuery: query,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  List<dynamic> _filterVendors(List<dynamic> vendors, String query) {
    if (query.isEmpty) return [];
    final queryLower = query.toLowerCase();
    return vendors.where((v) {
      final nameMatch = v.name.toLowerCase().contains(queryLower);
      final cuisineMatch = v.cuisineType.toLowerCase().contains(queryLower);
      final vendorTagMatch = v.tags?.any((tag) => tag.toLowerCase().contains(queryLower)) ?? false;
      final productMatch = v.products?.any((p) {
        return p.name.toLowerCase().contains(queryLower) || 
               p.description.toLowerCase().contains(queryLower) ||
               p.tags?.any((tag) => tag.toLowerCase().contains(queryLower)) == true;
      }) ?? false;
      return nameMatch || cuisineMatch || vendorTagMatch || productMatch;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(Icons.eco_outlined, size: 64, color: AppColors.brandGreen.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            const Text("No kitchens found for this craving", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text("Try searching for something else healthy", style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
