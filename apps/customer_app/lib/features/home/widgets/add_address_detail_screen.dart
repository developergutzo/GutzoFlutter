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

class AddAddressDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<AddAddressDetailScreen> createState() => _AddAddressDetailScreenState();
}

class _AddAddressDetailScreenState extends ConsumerState<AddAddressDetailScreen> {
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
  bool _initialTypeSet = false;

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
      _initialTypeSet = true;
    } else {
      // Pre-fill from geocoding with enhanced components
      final house = widget.address.houseNumber ?? widget.address.streetNumber ?? '';
      final flat = widget.address.flatNumber ?? '';
      final building = widget.address.buildingName ?? '';
      final block = widget.address.block ?? '';
      final area = widget.address.area ?? '';
      final route = widget.address.route ?? '';
      
      // Combine House/Flat/Block/Building for the specific premise field
      List<String> houseParts = [];
      if (house.isNotEmpty) houseParts.add(house);
      if (flat.isNotEmpty) houseParts.add(flat);
      if (block.isNotEmpty) houseParts.add(block);
      if (building.isNotEmpty) houseParts.add(building);
      
      if (houseParts.isNotEmpty) {
        _houseController.text = houseParts.join(', ');
      } else {
        // Fallback: auto populate with the most specific available address part
        final splitAddr = widget.address.formattedAddress.split(',');
        if (splitAddr.isNotEmpty && splitAddr[0].trim().isNotEmpty) {
          _houseController.text = splitAddr[0].trim();
        }
      }
      
      // Combine Road/Area
      List<String> areaParts = [];
      if (route.isNotEmpty) areaParts.add(route);
      if (area.isNotEmpty && !route.contains(area)) areaParts.add(area);
      
      _areaController.text = areaParts.join(', ');
      _pincodeController.text = widget.address.postalCode ?? '';
    }
    
    // Listeners for UI updates (glow effects & real-time validation)
    _houseFocus.addListener(() => setState(() {}));
    _areaFocus.addListener(() => setState(() {}));
    _pincodeFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _customFocus.addListener(() => setState(() {}));

    // Listeners for real-time button enabling
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

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final label = _selectedCategory == 'home' 
        ? 'Home' 
        : _selectedCategory == 'work' 
            ? 'Work' 
            : 'Other';

      final Map<String, dynamic> addressData = {
        'label': label,
        'street': _houseController.text.trim(),
        'area': _areaController.text.trim().isEmpty ? _houseController.text.trim() : _areaController.text.trim(),
        'full_address': widget.existingAddress != null ? widget.existingAddress!.fullAddress : widget.address.formattedAddress,
        'zipcode': _pincodeController.text.trim(),
        'latitude': widget.position.latitude,
        'longitude': widget.position.longitude,
        'is_default': false,
        if (_selectedCategory == 'other') 'custom_label': _customLabelController.text.trim(),
        if (_phoneController.text.isNotEmpty) 'alternative_phone': _phoneController.text.trim(),
      };

      if (widget.existingAddress != null) {
        await ref.read(nodeApiServiceProvider).updateAddress(user.phone, widget.existingAddress!.id, addressData);
      } else {
        await ref.read(nodeApiServiceProvider).createAddress(user.phone, addressData);
      }
      
      if (mounted) {
        ref.invalidate(savedAddressesProvider);
        // Pop back to the Saved Addresses list (Detail -> Picker)
        // This will land the user back on the LocationSheet which refreshes automatically
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(savedAddressesProvider);
    final addresses = addressesAsync.value ?? [];
    
    final hasHome = addresses.any((a) {
      final label = (a.label ?? '').trim().toLowerCase();
      return label == 'home' || a.type == 'home';
    });
    final hasWork = addresses.any((a) {
      final label = (a.label ?? '').trim().toLowerCase();
      return label == 'work' || a.type == 'work';
    });

    // Smart default selection on first load
    if (!_initialTypeSet && addressesAsync.hasValue) {
      if (!hasHome) {
        _selectedCategory = 'home';
      } else if (!hasWork) {
        _selectedCategory = 'work';
      } else {
        _selectedCategory = 'other';
      }
      _initialTypeSet = true;
    }

    // Real-time validation logic
    final houseVal = _houseController.text.trim();
    final pincodeVal = _pincodeController.text.trim();
    final customVal = _customLabelController.text.trim();
    
    bool isFormValid = houseVal.isNotEmpty && 
                       pincodeVal.length == 6 && 
                       RegExp(r'^\d{6}$').hasMatch(pincodeVal);
    
    if (_selectedCategory == 'other' && customVal.isEmpty) {
      isFormValid = false;
    }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary box (Read-only)
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
                  _buildCategoryPill('home', Icons.home_outlined, 'Home', hasHome),
                  const SizedBox(width: 12),
                  _buildCategoryPill('work', Icons.work_outline, 'Work', hasWork),
                  const SizedBox(width: 12),
                  _buildCategoryPill('other', Icons.place_outlined, 'Other', false),
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

  Widget _buildCategoryPill(String id, IconData icon, String label, bool isTaken) {
    bool isSelected = _selectedCategory == id;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isTaken) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You already have a $label address. Please choose a different label or use \'Other\' for a unique name.',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                backgroundColor: AppColors.textMain,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            return;
          }
          setState(() => _selectedCategory = id);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandGreen : (isTaken ? Colors.grey.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.brandGreen : (isTaken ? Colors.grey.shade200 : AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                color: isSelected ? Colors.white : (isTaken ? Colors.grey.shade300 : AppColors.textSub), 
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : (isTaken ? Colors.grey.shade300 : AppColors.textSub),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
