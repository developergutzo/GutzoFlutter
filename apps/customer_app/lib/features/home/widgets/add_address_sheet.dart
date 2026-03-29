import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/services/location_service.dart';

class AddAddressSheet extends ConsumerStatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialAddress;

  const AddAddressSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
  });

  static void show(BuildContext context, {
    required double lat,
    required double lng,
    required String address,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAddressSheet(
        initialLat: lat,
        initialLng: lng,
        initialAddress: address,
      ),
    );
  }

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  GoogleMapController? _mapController;
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customLabelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _streetFocus = FocusNode();
  final FocusNode _areaFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _customLabelFocus = FocusNode();
  final FocusNode _searchFocus = FocusNode();

  String _selectedType = 'home';
  String _fullAddress = '';
  double _currentLat = 0;
  double _currentLng = 0;
  bool _isGeocoding = false;
  List<AutocompletePrediction> _predictions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _fullAddress = widget.initialAddress;

    // Add listeners for reactive glow
    _streetFocus.addListener(() => setState(() {}));
    _areaFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _customLabelFocus.addListener(() => setState(() {}));
    _searchFocus.addListener(() => setState(() {}));

    // Initial auto-fill
    _reverseGeocode(_currentLat, _currentLng);
  }

  @override
  void dispose() {
    _streetController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    _customLabelController.dispose();
    _searchController.dispose();

    _streetFocus.dispose();
    _areaFocus.dispose();
    _phoneFocus.dispose();
    _customLabelFocus.dispose();
    _searchFocus.dispose();

    _debounce?.cancel();
    super.dispose();
  }

  void _populateAddressFields(DetailedAddress detailed) {
    final address = detailed.formattedAddress;
    final parts = address.split(',').map((p) => p.trim()).toList();

    // The web app primarily uses the first part for the street field
    String primaryStreet = parts.isNotEmpty ? parts[0] : '';
    
    // Check if the first part is a Plus Code (e.g., "5VFC+3H9") and skip it if it is
    if (primaryStreet.contains('+') && primaryStreet.length <= 10 && parts.length > 1) {
      primaryStreet = parts[1];
      // If we skipped a Plus Code, the "Area" might be the next part
      _areaController.text = parts.length > 2 ? parts[2] : (detailed.area ?? '');
    } else {
      // Matching web behavior: parts[1] is often used for the area field when components are sparse
      _areaController.text = detailed.area ?? (parts.length > 1 ? parts[1] : '');
    }

    _streetController.text = primaryStreet;
    
    // If street is still empty but we have geocoded components, use them as fallback
    if (_streetController.text.isEmpty) {
      _streetController.text = detailed.streetNumber != null 
          ? '${detailed.streetNumber}, ${detailed.route ?? ''}'
          : (detailed.route ?? '');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _isGeocoding = true);
    final detailed = await LocationService.reverseGeocodeDetailed(lat, lng);
    if (mounted && detailed != null) {
      setState(() {
        _fullAddress = detailed.formattedAddress;
        _populateAddressFields(detailed);
        _isGeocoding = false;
      });
    } else if (mounted) {
      setState(() => _isGeocoding = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await LocationService.searchLocation(query);
      if (mounted) setState(() => _predictions = results);
    });
  }

  void _selectPrediction(AutocompletePrediction prediction) async {
    final details = await LocationService.fetchPlaceDetails(prediction.placeId);
    if (details != null && mounted) {
      setState(() {
        _currentLat = details.latitude;
        _currentLng = details.longitude;
        _fullAddress = details.formattedAddress;
        _populateAddressFields(details);
        _predictions = [];
        _searchController.clear();
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(_currentLat, _currentLng)));
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    bool isRequired = false,
    TextInputType type = TextInputType.text,
  }) {
    final hasFocus = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: hasFocus ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus ? AppColors.brandGreen : AppColors.border,
              width: hasFocus ? 2.5 : 1.0,
            ),
            boxShadow: hasFocus
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
            controller: controller,
            focusNode: focusNode,
            keyboardType: type,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeButton(String type, IconData icon, String label) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandGreen.withValues(alpha: 0.05) : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.brandGreen : AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.brandGreen : AppColors.textSub,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.brandGreen : AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Delivery Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  splashRadius: 24,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Input
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _searchFocus.hasFocus ? AppColors.brandGreen : AppColors.border,
                            width: _searchFocus.hasFocus ? 2.5 : 1.0,
                          ),
                          boxShadow: _searchFocus.hasFocus
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
                          focusNode: _searchFocus,
                          onTap: () => setState(() {}),
                          onTapOutside: (_) {
                            _searchFocus.unfocus();
                            setState(() {});
                          },
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search for area, street name...',
                            hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 14),
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

                      // Map View
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(_currentLat, _currentLng),
                                  zoom: 15,
                                ),
                                onMapCreated: (controller) => _mapController = controller,
                                onCameraMove: (position) {
                                  _currentLat = position.target.latitude;
                                  _currentLng = position.target.longitude;
                                },
                                onCameraIdle: () {
                                  _reverseGeocode(_currentLat, _currentLng);
                                },
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                  Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer(),
                                  ),
                                },
                              ),
                              // Fixed Center Marker
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 24), // Offset for pin foot
                                  child: Icon(
                                    Icons.location_on,
                                    color: AppColors.ctaOrange,
                                    size: 36,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: FloatingActionButton.small(
                                  onPressed: () async {
                                    try {
                                      final location = await LocationService.getCurrentLocation();
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error getting location: $e')),
                                        );
                                      }
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  child: const Icon(Icons.my_location, color: AppColors.brandGreen, size: 18),
                                ),
                              ),
                              if (_isGeocoding)
                                Container(
                                  color: Colors.black12,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Location Text
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: AppColors.brandGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Location:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fullAddress,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Detailed Form
                      _buildTextField(
                        label: 'House / Flat / Block No.',
                        hint: 'Enter house/flat number',
                        controller: _streetController,
                        focusNode: _streetFocus,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Apartment / Road / Area (Optional)',
                        hint: 'Enter area details',
                        controller: _areaController,
                        focusNode: _areaFocus,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Phone Number (Alternative Contact)',
                        hint: 'Enter phone number',
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        type: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),

                      // Save As
                      const Text(
                        'Save as',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTypeButton('home', Icons.home_outlined, 'Home'),
                          const SizedBox(width: 12),
                          _buildTypeButton('work', Icons.work_outline, 'Work'),
                          const SizedBox(width: 12),
                          _buildTypeButton('other', Icons.place_outlined, 'Other'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_selectedType == 'other')
                        _buildTextField(
                          label: 'Custom Label',
                          hint: "Enter label (e.g. Mom's House)",
                          controller: _customLabelController,
                          focusNode: _customLabelFocus,
                          isRequired: true,
                        ),
                      
                      SizedBox(height: 80 + keyboardPadding),
                    ],
                  ),
                ),

                // Search Results Overlay
                if (_predictions.isNotEmpty)
                  Positioned(
                    top: 72,
                    left: 20,
                    right: 20,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Search Results',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSub,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _predictions.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade100,
                                indent: 48,
                              ),
                              itemBuilder: (context, index) {
                                final p = _predictions[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey.shade50,
                                    child: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSub),
                                  ),
                                  title: Text(
                                    p.mainText,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textMain),
                                  ),
                                  subtitle: Text(
                                    p.secondaryText,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSub),
                                  ),
                                  onTap: () => _selectPrediction(p),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'powered by Google',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Footer Button
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Logic to save address
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save and Proceed',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
