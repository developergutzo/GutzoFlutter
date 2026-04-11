import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/search_service.dart';
import '../../search/search_results_screen.dart';

class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Search',
      barrierColor: kIsWeb ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final child = const SearchSheet();
        if (kIsWeb) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: child,
                ),
              ),
            ],
          );
        }
        return child;
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        if (kIsWeb) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        }
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(WidgetRef ref, String query) {
    if (query.trim().isEmpty) return;
    
    // Save to history
    ref.read(searchServiceProvider.notifier).addSearch(query);
    
    // Close the top-sheet dialog
    Navigator.of(context).pop();
    
    // Push the results screen (Right-to-Left animation)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final recentSearches = ref.watch(searchServiceProvider);

        return Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: kIsWeb ? BorderRadius.circular(28) : const BorderRadius.vertical(bottom: Radius.circular(28)),
                  border: kIsWeb ? Border.all(color: AppColors.webGlassBorder, width: 0.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: kIsWeb ? 0.08 : 0.1),
                      blurRadius: kIsWeb ? 32 : 10,
                      offset: Offset(0, kIsWeb ? 16 : 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(28, kIsWeb ? 32 : 60, 28, 32),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upper Label (Pixel Perfect match)
                      const Text(
                        "what's your gut feeling today?",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Search Input Field
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        cursorColor: AppColors.brandGreen,
                        onSubmitted: (query) => _onSearch(ref, query),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: "Find your next favorite meal...",
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF111827), size: 24),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.brandGreen, width: 2.0),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      
                      if (recentSearches.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        // Recent Searches Title
                        const Text(
                          "Your Recent Searches",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // Recent Search Chips
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: recentSearches.take(8).map((search) => _buildRecentChip(ref, search)).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Dismissible area below the sheet
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentChip(WidgetRef ref, String label) {
    return InkWell(
      onTap: () => _onSearch(ref, label),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

