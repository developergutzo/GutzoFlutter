import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/vendor_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../../widgets/vendor_card.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Reactive Header (Premium UX)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textMain, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isFocused ? Colors.white : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFocused ? AppColors.brandGreen : const Color(0xFFF3F4F6),
                          width: _isFocused ? 2.5 : 1.0,
                        ),
                        boxShadow: _isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.brandGreen.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onTap: () => setState(() => _isFocused = true),
                        onTapOutside: (_) {
                          _focusNode.unfocus();
                          setState(() => _isFocused = false);
                        },
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search kitchens...",
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: vendorsAsync.when(
                data: (vendors) {
                  final filteredVendors = vendors.where((v) {
                    final queryLower = query.toLowerCase();
                    
                    // Match kitchen name or cuisine
                    final nameMatch = v.name.toLowerCase().contains(queryLower);
                    final cuisineMatch = v.cuisineType.toLowerCase().contains(queryLower);
                    
                    // Match kitchen tags
                    final vendorTagMatch = v.tags?.any((tag) => tag.toLowerCase().contains(queryLower)) ?? false;
                    
                    // Match products (name, description, or tags)
                    final productMatch = v.products?.any((p) {
                      final pNameMatch = p.name.toLowerCase().contains(queryLower);
                      final pDescMatch = p.description.toLowerCase().contains(queryLower);
                      final pTagMatch = p.tags?.any((tag) => tag.toLowerCase().contains(queryLower)) ?? false;
                      return pNameMatch || pDescMatch || pTagMatch;
                    }) ?? false;

                    return nameMatch || cuisineMatch || vendorTagMatch || productMatch;
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Result Headline
                      Text.rich(
                        TextSpan(
                          text: 'Search results for ',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(
                              text: '"${_searchController.text}"',
                              style: const TextStyle(color: AppColors.brandGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Found ${filteredVendors.length} kitchens',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Results List
                      if (filteredVendors.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.eco_outlined, 
                                  size: 48, 
                                  color: AppColors.brandGreen.withValues(alpha: 0.2)
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "No kitchens found for this craving",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMain,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Try searching for another healthy item",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSub,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filteredVendors.map((vendor) => Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: VendorCard(
                                imageUrl: vendor.image,
                                title: vendor.name,
                                cuisine: vendor.cuisineType,
                                deliveryTime: vendor.deliveryTime,
                                rating: vendor.rating,
                                vendorModel: vendor,
                                searchQuery: _searchController.text,
                              ),
                            )),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
