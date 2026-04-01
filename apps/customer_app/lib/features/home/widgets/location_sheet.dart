import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/services/auth_service.dart' as auth;
import 'package:shared_core/services/node_api_service.dart' as api;
import 'package:shared_core/models/address.dart';
import '../../../providers/address_provider.dart';
import 'add_address_sheet.dart';

class LocationSheet extends ConsumerStatefulWidget {
  const LocationSheet({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const LocationSheet()),
    );
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
  String? _selectedAddressId;

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
        ),
      );
    }
    Navigator.of(context).pop();
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
    final isSelected = _selectedAddressId == address.id || address.isDefault;
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
                    // TODO: open edit address sheet
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
    final areaName = locationState.location?.areaName ?? 'Detecting...';
    final stateName = locationState.location?.state ?? '';
    final paddingBottom = MediaQuery.of(context).viewInsets.bottom;
    final addressesAsync = ref.watch(savedAddressesProvider);

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
      body: Padding(
        padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Search Field
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchFocus.hasFocus ? AppColors.brandGreen : AppColors.border,
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onTap: () => setState(() {}),
                onTapOutside: (_) {
                  _searchFocus.unfocus();
                  setState(() {});
                },
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search for area, street name...',
                  hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: AppColors.brandGreen, size: 20),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Horizontal Actions: Current Location & Add Address
            Row(
              children: [
                // Use Current Location
                Expanded(
                  child: InkWell(
                    onTap: isDetecting
                        ? null
                        : () async {
                            await ref.read(locationProvider.notifier).refreshLocation();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brandGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: isDetecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.brandGreen,
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: AppColors.brandGreen, size: 18),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add/Manage Addresses
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final loc = locationState.location;
                      if (loc != null) {
                        AddAddressSheet.show(context, lat: loc.latitude, lng: loc.longitude, address: loc.displayString);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brandGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_location_alt_outlined, color: AppColors.brandGreen, size: 18),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add New Address',
                            style: TextStyle(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (!_isSearching) ...[
              const Text(
                'Saved Addresses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMain),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: addressesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen),
                  ),
                  error: (_, __) => const Center(
                    child: Text(
                      'Failed to load addresses',
                      style: TextStyle(color: AppColors.textSub, fontSize: 14),
                    ),
                  ),
                  data: (addresses) {
                    if (addresses.isEmpty) {
                      return const Center(
                        child: Text(
                          'No saved addresses found.',
                          style: TextStyle(color: AppColors.textSub, fontSize: 14),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: EdgeInsets.only(bottom: paddingBottom + 24),
                      itemCount: addresses.length,
                      itemBuilder: (ctx, i) => _buildAddressCard(addresses[i]),
                    );
                  },
                ),
              ),
            ] else ...[
              const Text(
                'Search Results',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSub),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _predictions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 40, color: AppColors.border),
                            SizedBox(height: 12),
                            Text(
                              'No locations found for this query.',
                              style: TextStyle(color: AppColors.textSub, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(bottom: paddingBottom + 24),
                        itemCount: _predictions.length + 1,
                        separatorBuilder: (_, i) => i == _predictions.length - 1
                            ? const SizedBox.shrink()
                            : const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (_, i) {
                          if (i == _predictions.length) {
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
                          final p = _predictions[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined, color: AppColors.textSub),
                            title: Text(
                              p.mainText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              p.secondaryText,
                              style: const TextStyle(color: AppColors.textSub, fontSize: 13),
                            ),
                            onTap: () => Navigator.of(context).pop(),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
