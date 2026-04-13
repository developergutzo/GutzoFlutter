import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/models/address.dart';
import '../../../providers/address_provider.dart';
import '../../auth/auth_screen.dart';

class AddAddressDetailScreen extends StatelessWidget {
  final LatLng position;
  final DetailedAddress address;
  final UserAddress? existingAddress;

  const AddAddressDetailScreen({
    super.key,
    required this.position,
    required this.address,
    this.existingAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Add Address Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textMain),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: AddAddressDetailView(
        position: position,
        address: address,
        existingAddress: existingAddress,
      ),
    );
  }
}

class AddAddressDetailView extends ConsumerStatefulWidget {
  final LatLng position;
  final DetailedAddress address;
  final UserAddress? existingAddress;
  final bool isEmbedded;
  final VoidCallback? onSaved;

  const AddAddressDetailView({
    super.key,
    required this.position,
    required this.address,
    this.existingAddress,
    this.isEmbedded = false,
    this.onSaved,
  });

  @override
  ConsumerState<AddAddressDetailView> createState() => _AddAddressDetailViewState();
}

class _AddAddressDetailViewState extends ConsumerState<AddAddressDetailView> {
  final _formKey = GlobalKey<FormState>();
  final _houseController = TextEditingController();
  final _areaController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customLabelController = TextEditingController();

  final _houseFocus = FocusNode();
  final _areaFocus = FocusNode();
  final _pincodeFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _customFocus = FocusNode();

  String _selectedCategory = 'home';
  bool _isSaving = false;
  bool _userManuallySetType = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingAddress != null) {
      final addr = widget.existingAddress!;
      _houseController.text = addr.street;
      _areaController.text = addr.area ?? '';
      _pincodeController.text = addr.postalCode ?? '';
      _phoneController.text = addr.alternativePhone ?? '';
      _customLabelController.text = addr.customLabel ?? '';
      _selectedCategory = addr.type;
      // Initial category selection is now handled reactively in build()
    } else {
      final house = widget.address.houseNumber ?? widget.address.streetNumber ?? '';
      final flat = widget.address.flatNumber ?? '';
      final building = widget.address.buildingName ?? '';
      final block = widget.address.block ?? '';
      final area = widget.address.area ?? '';
      final route = widget.address.route ?? '';
      
      List<String> houseParts = [];
      if (house.isNotEmpty) houseParts.add(house);
      if (flat.isNotEmpty) houseParts.add(flat);
      if (block.isNotEmpty) houseParts.add(block);
      if (building.isNotEmpty) houseParts.add(building);
      
      if (houseParts.isNotEmpty) {
        _houseController.text = houseParts.join(', ');
      } else {
        final splitAddr = widget.address.formattedAddress.split(',');
        if (splitAddr.isNotEmpty && splitAddr[0].trim().isNotEmpty) {
          _houseController.text = splitAddr[0].trim();
        }
      }
      
      List<String> areaParts = [];
      if (route.isNotEmpty) areaParts.add(route);
      if (area.isNotEmpty && !route.contains(area)) areaParts.add(area);
      
      _areaController.text = areaParts.join(', ');
      _pincodeController.text = widget.address.postalCode ?? '';
    }
    
    _houseFocus.addListener(() => setState(() {}));
    _areaFocus.addListener(() => setState(() {}));
    _pincodeFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _customFocus.addListener(() => setState(() {}));

    _houseController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _customLabelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _houseController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _customLabelController.dispose();
    _houseFocus.dispose();
    _areaFocus.dispose();
    _pincodeFocus.dispose();
    _phoneFocus.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    var user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        await Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const AuthScreen()),
        );
        user = ref.read(currentUserProvider);
      }
      if (user == null) return;
    }

    // Removing automatic _isSaving = true here to avoid "phantom" loading button after login.
    // It will only be set to true if the final duplicate check passes.

    // Step 4: Synchronized Verification Delay
    try {
      debugPrint('Step 4: Synchronizing address list before final save...');
      await ref.read(savedAddressesProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Step 4 Error: Failed to sync addresses: $e');
    }

    // Final duplicate check before calling API
    final addresses = ref.read(savedAddressesProvider).value ?? [];
    final lowerTarget = _selectedCategory == 'home' 
        ? 'home' 
        : _selectedCategory == 'work' 
            ? 'work' 
            : _customLabelController.text.trim().toLowerCase();
    
    final isDuplicate = addresses.any((a) {
      if (widget.existingAddress != null && a.id == widget.existingAddress!.id) return false;
      final existingLabel = (a.label ?? '').trim().toLowerCase();
      final existingType = (a.type ?? '').trim().toLowerCase();
      return (lowerTarget == 'home' && (existingLabel == 'home' || existingType == 'home')) ||
             (lowerTarget == 'work' && (existingLabel == 'work' || existingType == 'work'));
    });

    if (isDuplicate) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final label = _selectedCategory == 'home' 
        ? 'Home' 
        : _selectedCategory == 'work' 
            ? 'Work' 
            : 'Other';

      final Map<String, dynamic> addressData = {
        'type': _selectedCategory, // Explicitly send the category type
        'label': label,
        'street': _houseController.text.trim(),
        'area': _areaController.text.trim().isEmpty ? _houseController.text.trim() : _areaController.text.trim(),
        'full_address': widget.existingAddress != null ? widget.existingAddress!.fullAddress : widget.address.formattedAddress,
        'zipcode': _pincodeController.text.trim(),
        'latitude': widget.position.latitude,
        'longitude': widget.position.longitude,
        'city': widget.address.city ?? '',
        'state': widget.address.state ?? '',
        'country': widget.address.country ?? '',
        'is_default': false,
        if (_selectedCategory == 'other') 'custom_label': _customLabelController.text.trim(),
        if (_phoneController.text.isNotEmpty) 'alternative_phone': _phoneController.text.trim(),
      };

      dynamic response;
      if (widget.existingAddress != null) {
        response = await ref.read(nodeApiServiceProvider).updateAddress(user.phone, widget.existingAddress!.id, addressData);
      } else {
        response = await ref.read(nodeApiServiceProvider).createAddress(user.phone, addressData);
      }
      
      if (mounted) {
        // Extract the saved address object (usually response['data'] or response)
        final savedJson = response['data'] ?? response;
        if (savedJson != null && savedJson is Map) {
          final savedAddress = UserAddress.fromJson(Map<String, dynamic>.from(savedJson));
          debugPrint('📍 Address saved successfully! Overriding global location: ${savedAddress.fullAddress}');
          
          // Proactively set this as the active location so Homepage shows it immediately
          ref.read(locationProvider.notifier).overrideLocation(
            LocationData.fromUserAddress(savedAddress),
          );
        }

        if (mounted) {
          _showSubtleSnackBar('Address saved successfully!');
        }

        ref.read(savedAddressesProvider.notifier).refresh();
        if (widget.isEmbedded && widget.onSaved != null) {
          widget.onSaved!();
        } else {
          // Double pop to go back to Home
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('🚨 Save Address Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(savedAddressesProvider);
    final addresses = addressesAsync.value ?? [];
    
    final hasHome = addresses.any((a) {
      if (widget.existingAddress != null && a.id == widget.existingAddress!.id) return false;
      final label = (a.label ?? '').trim().toLowerCase();
      final type = (a.type ?? '').trim().toLowerCase();
      final isHome = label == 'home' || type == 'home';
      if (isHome) debugPrint('Duplicate Detection: Found existing Home address with ID: ${a.id}');
      return isHome;
    });

    final hasWork = addresses.any((a) {
      if (widget.existingAddress != null && a.id == widget.existingAddress!.id) return false;
      final label = (a.label ?? '').trim().toLowerCase();
      final type = (a.type ?? '').trim().toLowerCase();
      final isWork = label == 'work' || type == 'work';
      if (isWork) debugPrint('Duplicate Detection: Found existing Work address with ID: ${a.id}');
      return isWork;
    });

    final bool isLoading = addressesAsync.isLoading;
    debugPrint('Duplicate Status: hasHome=$hasHome, hasWork=$hasWork, isLoading=$isLoading, TotalAddresses=${addresses.length}');

    // Sanity Check: If the selected category is ALREADY taken (e.g. user chose Home as guest but already has Home),
    // we MUST pivot away from it to prevent duplicates, even if _userManuallySetType is true.
    if (_selectedCategory == 'home' && hasHome) {
      _selectedCategory = hasWork ? 'other' : 'work';
      _userManuallySetType = false; // Reset to allow subsequent auto-switching if needed
    } else if (_selectedCategory == 'work' && hasWork) {
      _selectedCategory = 'other';
      _userManuallySetType = false;
    }

    // Default selection logic (Initial set)
    if (!_userManuallySetType && addressesAsync.hasValue) {
      if (widget.existingAddress != null) {
        _selectedCategory = widget.existingAddress!.type ?? 'other';
        if (_selectedCategory == 'other' && widget.existingAddress!.label != null) {
          _customLabelController.text = widget.existingAddress!.label!;
        }
      } else {
        // Find first available slot
        if (!hasHome) {
          _selectedCategory = 'home';
        } else if (!hasWork) {
          _selectedCategory = 'work';
        } else {
          _selectedCategory = 'other';
        }
      }
    }

    final houseVal = _houseController.text.trim();
    final pincodeVal = _pincodeController.text.trim();
    final customVal = _customLabelController.text.trim();
    
    bool isFormValid = houseVal.isNotEmpty && 
                       pincodeVal.length == 6 && 
                       RegExp(r'^\d{6}$').hasMatch(pincodeVal);
    
    // Step 3: Absolute Block - Disable save button if duplicate active
    if (_selectedCategory == 'home' && hasHome) {
      isFormValid = false;
      debugPrint('Step 3: Disabling Save - Home already taken.');
    } else if (_selectedCategory == 'work' && hasWork) {
      isFormValid = false;
      debugPrint('Step 3: Disabling Save - Work already taken.');
    }
    
    // Also block if they type "home"/"work" in "other" field
    final lowerCustom = customVal.toLowerCase();
    if (_selectedCategory == 'other') {
      if (lowerCustom.isEmpty) {
        isFormValid = false;
      } else if ((lowerCustom == 'home' && hasHome) || (lowerCustom == 'work' && hasWork)) {
        isFormValid = false;
        debugPrint('Step 3: Disabling Save - Custom label is a taken primary type ($lowerCustom).');
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: AppColors.brandGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.address.area ?? 'Selected Point',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textMain),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.address.formattedAddress,
                            style: GoogleFonts.poppins(color: AppColors.textSub, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildField(
                label: 'House / Flat / Block No.',
                controller: _houseController,
                focusNode: _houseFocus,
                hint: 'e.g. 287, 4th Floor',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                label: 'Apartment / Road / Area',
                controller: _areaController,
                focusNode: _areaFocus,
                hint: 'e.g. Teachers Colony',
              ),
              const SizedBox(height: 20),

              _buildField(
                label: 'Pincode',
                controller: _pincodeController,
                focusNode: _pincodeFocus,
                hint: '6-digit pincode',
                keyboardType: TextInputType.number,
                validator: (v) => v!.length != 6 ? 'Enter valid 6-digit pincode' : null,
              ),
              const SizedBox(height: 20),

              _buildField(
                label: 'Alternative Contact Number (Optional)',
                controller: _phoneController,
                focusNode: _phoneFocus,
                hint: 'e.g. 9876543210',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),

              Text(
                'Save as',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textMain),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCategoryPill('home', Icons.home_outlined, 'Home', hasHome, isLoading),
                  const SizedBox(width: 12),
                  _buildCategoryPill('work', Icons.work_outline, 'Work', hasWork, isLoading),
                  const SizedBox(width: 12),
                  _buildCategoryPill('other', Icons.place_outlined, 'Other', false, isLoading),
                ],
              ),

              if (_selectedCategory == 'other') ...[
                const SizedBox(height: 20),
                _buildField(
                  label: '',
                  controller: _customLabelController,
                  focusNode: _customFocus,
                  hint: "e.g. Mom's House",
                  validator: (v) => _selectedCategory == 'other' && v!.isEmpty ? 'Required' : null,
                ),
              ],

              const SizedBox(height: 48),
              
              ElevatedButton(
                onPressed: (_isSaving || !isFormValid) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.brandGreen.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Address', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final hasFocus = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: hasFocus ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFocus ? AppColors.brandGreen : AppColors.border,
              width: hasFocus ? 2 : 1,
            ),
            boxShadow: hasFocus ? [
               BoxShadow(color: AppColors.brandGreen.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)
            ] : [],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: AppColors.textDisabled, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String id, IconData icon, String label, bool isTaken, bool isLoading) {
    bool isSelected = _selectedCategory == id;
    return Expanded(
      child: Opacity(
        opacity: (isTaken || isLoading) ? 0.6 : 1.0,
        child: InkWell(
          onTap: () {
            if (isLoading) return; // Prevent interaction while loading server data
            if (isTaken) return;
            setState(() {
              _selectedCategory = id;
              _userManuallySetType = true;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brandGreen : (isTaken ? Colors.grey.shade100 : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.brandGreen : (isTaken ? Colors.grey.shade300 : AppColors.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  color: isSelected ? Colors.white : (isTaken ? Colors.grey.shade400 : AppColors.textSub), 
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : (isTaken ? Colors.grey.shade400 : AppColors.textSub),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSubtleSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2C2C2C), // True neutral charcoal, zero red
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
