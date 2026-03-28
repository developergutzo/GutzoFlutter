import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/location_service.dart';
import 'add_address_sheet.dart';

class LocationSheet extends ConsumerStatefulWidget {
  const LocationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSheet(),
    );
  }

  @override
  ConsumerState<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<LocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<AutocompletePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await LocationService.searchLocation(query);
      if (mounted) {
        setState(() {
          _predictions = results;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current location state to display below the button.
    final locationState = ref.watch(locationProvider);
    final isDetecting = locationState.isLoading;
    final areaName = locationState.location?.areaName ?? 'Detecting...';
    // Provide a state name if available, otherwise hide it.
    final stateName = locationState.location?.state ?? '';

    // Adjusting for keyboard
    final paddingBottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      // Make it slightly shorter than full screen, like standard bottom sheets.
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSub),
                splashRadius: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search for area, street name...',
                hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: AppColors.brandGreen, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Use Current Location
          InkWell(
            onTap: isDetecting
                ? null
                : () async {
                    // Refresh location
                    await ref.read(locationProvider.notifier).refreshLocation();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isDetecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandGreen,
                            ),
                          )
                        : const Icon(Icons.my_location,
                            color: AppColors.brandGreen, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Use current location',
                          style: TextStyle(
                            color: AppColors.brandGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stateName.isNotEmpty ? '$areaName, $stateName' : areaName,
                          style: const TextStyle(
                            color: AppColors.textSub,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textDisabled),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Conditional Content Based on Search Status
          if (!_isSearching) ...[
            // Add / Manage Addresses Button
            ElevatedButton.icon(
              onPressed: () {
                final loc = locationState.location;
                if (loc != null) {
                  AddAddressSheet.show(
                    context,
                    lat: loc.latitude,
                    lng: loc.longitude,
                    address: loc.displayString,
                  );
                }
              },
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              label: const Text(
                'Add/Manage Addresses',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),

            // Saved Addresses Section
            const Text(
              'Saved Addresses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: paddingBottom + 24),
                child: const Center(
                  child: Text(
                    'No saved addresses found.',
                    style: TextStyle(
                      color: AppColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Search Results',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSub,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _predictions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.search_off,
                              size: 40, color: AppColors.border),
                          SizedBox(height: 12),
                          Text(
                            'No locations found for this query.',
                            style: TextStyle(
                                color: AppColors.textSub, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(bottom: paddingBottom + 24),
                      itemCount: _predictions.length + 1,
                      separatorBuilder: (context, index) {
                        if (index == _predictions.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return const Divider(color: AppColors.border, height: 1);
                      },
                      itemBuilder: (context, index) {
                        if (index == _predictions.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8, right: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'powered by Google',
                                style: TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }

                        final prediction = _predictions[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.textSub),
                          title: Text(
                            prediction.mainText,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            prediction.secondaryText,
                            style: const TextStyle(
                                color: AppColors.textSub, fontSize: 13),
                          ),
                          onTap: () {
                            // TODO: Implement coordinate fetching from placeId (Phase 3)
                            // For now, just close the sheet
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
