import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/services/auth_service.dart' as auth;
import 'package:shared_core/services/node_api_service.dart' as api;
import 'package:shared_core/models/address.dart';
import '../../../providers/address_provider.dart';
import 'location_pick_screen.dart';
import 'add_address_detail_screen.dart';
import '../../auth/auth_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationSheet extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onOpenMap;
  final VoidCallback? onAddNew;
  final VoidCallback? onLocationSelected;

  const LocationSheet({
    super.key,
    this.isEmbedded = false,
    this.onOpenMap,
    this.onAddNew,
    this.onLocationSelected,
  });

  static void show(BuildContext context) {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: const LocationSheet(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const LocationSheet()),
      );
    }
  }

  @override
  ConsumerState<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<LocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<AutocompletePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _isFetchingDetails = false;
  String? _selectedAddressId; // Still useful for immediate tap feedback


  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() { _predictions = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await LocationService.searchLocation(query);
      if (mounted) setState(() => _predictions = results);
    });
  }

  Future<void> _onPredictionSelected(AutocompletePrediction p) async {
    setState(() => _isFetchingDetails = true);
    try {
      final details = await LocationService.fetchPlaceDetails(p.placeId);
      if (details != null && mounted) {
        final newLoc = LocationData(
          city: details.city ?? '',
          state: details.state ?? '',
          country: details.country ?? '',
          formattedAddress: details.formattedAddress,
          latitude: details.latitude,
          longitude: details.longitude,
          timestamp: DateTime.now(),
          tag: p.mainText,
        );
        ref.read(locationProvider.notifier).overrideLocation(newLoc);
        if (widget.isEmbedded && widget.onLocationSelected != null) {
          widget.onLocationSelected!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load location details.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingDetails = false);
      }
    }
  }

  void _selectAddress(UserAddress address) {
    setState(() => _selectedAddressId = address.id);
    if (address.latitude != null && address.longitude != null) {
      ref.read(locationProvider.notifier).overrideLocation(
        LocationData(
          city: address.city,
          state: address.state,
          country: address.country,
          formattedAddress: address.fullAddress,
          latitude: address.latitude!,
          longitude: address.longitude!,
          timestamp: DateTime.now(),
          tag: address.customLabel ?? address.label ?? 'Other',
        ),
      );
    }
    if (widget.isEmbedded && widget.onLocationSelected != null) {
      widget.onLocationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  IconData _iconForLabel(String? label) {
    switch ((label ?? '').toLowerCase()) {
      case 'home': return Icons.home_outlined;
      case 'work': return Icons.work_outline;
      default: return Icons.place_outlined;
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, UserAddress address) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delete Address?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: AppColors.textMain, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this address?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSub,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F6F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'No',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteAddress(address);
                      },
                      child: Text(
                        'Yes',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(UserAddress address) {
    final locationState = ref.watch(locationProvider);
    final activeLoc = locationState.location;
    
    // Improved detection: Check if this address matches the currently active global location
    bool isSelected = false;
    if (activeLoc != null && address.latitude != null && address.longitude != null) {
      final double latDiff = (activeLoc.latitude - address.latitude!).abs();
      final double lngDiff = (activeLoc.longitude - address.longitude!).abs();
      // Use a small epsilon for coordinate matching
      if (latDiff < 0.0001 && lngDiff < 0.0001) {
        isSelected = true;
      }
    }
    
    final displayLabel = address.customLabel ?? address.label ?? 'Other';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.brandGreen : const Color(0xFFE8E8E8),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectAddress(address),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconForLabel(address.label), color: AppColors.brandGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayLabel,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                        const SizedBox(width: 8),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.brandGreen),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Selected',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandGreen)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSub, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSub, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                elevation: 4,
                onSelected: (val) {
                  if (val == 'edit') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => AddAddressDetailScreen(
                          position: LatLng(address.latitude ?? 0.0, address.longitude ?? 0.0),
                          address: DetailedAddress(
                            formattedAddress: address.fullAddress,
                            latitude: address.latitude ?? 0.0,
                            longitude: address.longitude ?? 0.0,
                          ),
                          existingAddress: address,
                        ),
                      ),
                    );
                  } else if (val == 'delete') {
                    _showDeleteConfirmationDialog(context, address);
                  } else if (val == 'default') {
                    ref.invalidate(savedAddressesProvider);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.textSub),
                      SizedBox(width: 10),
                      Text('Edit', style: TextStyle(fontSize: 14)),
                    ]),
                  ),
                  if (!address.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(children: [
                        Icon(Icons.star_outline, size: 16, color: AppColors.textSub),
                        SizedBox(width: 10),
                        Text('Set as Default', style: TextStyle(fontSize: 14)),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final user = ref.read(auth.currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(api.nodeApiServiceProvider).deleteAddress(user.phone, address.id);
      ref.invalidate(savedAddressesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete address: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _setDefault(UserAddress address) async {
    final user = ref.read(auth.currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(api.nodeApiServiceProvider).setDefaultAddress(user.phone, address.id);
      ref.invalidate(savedAddressesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set default address: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final isDetecting = locationState.isLoading;
    final paddingBottom = MediaQuery.of(context).viewInsets.bottom;
    final addressesAsync = ref.watch(savedAddressesProvider);

    if (widget.isEmbedded) {
      return _buildBody(context, paddingBottom, addressesAsync, isDetecting);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Select Location',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, 
            fontSize: 18, 
            color: AppColors.textMain,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(context, paddingBottom, addressesAsync, isDetecting),
    );
  }

  Widget _buildBody(BuildContext context, double paddingBottom, AsyncValue<List<UserAddress>> addressesAsync, bool isDetecting) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            const SizedBox(height: 16),
            _buildSearchField(),
            const SizedBox(height: 16),
            
            // Quick Actions: Current Location & Add Address
            Row(
              children: [
                Expanded(child: _buildActionButton(
                  icon: Icons.my_location,
                  label: 'Current Location',
                  isLoading: isDetecting,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const LocationPickScreen(isAddingAddress: false)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildActionButton(
                  icon: Icons.add_location_alt_outlined,
                  label: 'Add Address',
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const LocationPickScreen(isAddingAddress: true)),
                    );
                  },
                )),
              ],
            ),
            
            const SizedBox(height: 24),

            if (!_isSearching) ...[
              Text(
                'SAVED ADDRESSES',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: addressesAsync.when(
                  data: (addresses) {
                    if (addresses.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) => _buildAddressCard(addresses[index]),
                    );
                  },
                  loading: () => _buildShimmerList(),
                  error: (err, stack) => Center(child: Text('Error loading addresses')),
                ),
              ),
            ] else ...[
               Text(
                'SEARCH RESULTS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isFetchingDetails 
                  ? _buildShimmerList()
                  : ListView.builder(
                      itemCount: _predictions.length,
                      itemBuilder: (ctx, i) {
                        final p = _predictions[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.brandGreen, size: 22),
                          title: Text(p.mainText, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(p.secondaryText, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                          onTap: () => _onPredictionSelected(p),
                        );
                      },
                    ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchFocus.hasFocus ? AppColors.brandGreen : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search for area, street...',
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: AppColors.brandGreen, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen))
                : Icon(icon, color: AppColors.brandGreen, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandGreen),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.location_off_outlined, size: 70, color: Colors.grey[200]),
           const SizedBox(height: 20),
           Text(
             'No Addresses Found',
             style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600),
           ),
           const SizedBox(height: 8),
           Text(
             'Add a new coordinate to see it here',
             style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
           ),
         ],
       ),
     );
  }
}
