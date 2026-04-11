import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../auth/vendor_provider.dart';
import '../reports/gst_report_screen.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/models/vendor.dart';
import '../../common/widgets/skeletons.dart';
import '../../common/providers/loading_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with TickerProviderStateMixin {
  bool _isEditing = false;
  bool _hasChanges = false;
  Vendor? _initialVendor;
  late TabController _tabController;
  
  // Kitchen
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _cuisineController;
  late TextEditingController _locationController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  
  // Business
  late TextEditingController _ownerController;
  late TextEditingController _compTypeController;
  late TextEditingController _regNoController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _fssaiController;
  late TextEditingController _gstController;

  // Bank
  late TextEditingController _bankNameController;
  late TextEditingController _accHolderController;
  late TextEditingController _accNoController;
  late TextEditingController _ifscController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final vendor = ref.read(vendorProvider).value;
    _initControllers(vendor);
  }

  void _initControllers(Vendor? vendor) {
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _descController = TextEditingController(text: vendor?.description ?? '');
    _cuisineController = TextEditingController(text: vendor?.cuisineType ?? '');
    _locationController = TextEditingController(text: vendor?.location ?? '');
    _pincodeController = TextEditingController(text: vendor?.pincode ?? '');
    _phoneController = TextEditingController(text: vendor?.phone ?? '');

    _ownerController = TextEditingController(text: vendor?.ownerName ?? '');
    _compTypeController = TextEditingController(text: vendor?.companyType ?? '');
    _regNoController = TextEditingController(text: vendor?.companyRegNo ?? '');
    _aadharController = TextEditingController(text: vendor?.ownerAadharNo ?? '');
    _panController = TextEditingController(text: vendor?.panCardNo ?? '');
    _fssaiController = TextEditingController(text: vendor?.fssaiLicense ?? '');
    _gstController = TextEditingController(text: vendor?.gstNumber ?? '');

    _bankNameController = TextEditingController(text: vendor?.bankName ?? '');
    _accHolderController = TextEditingController(text: vendor?.accountHolderName ?? '');
    _accNoController = TextEditingController(text: vendor?.bankAccountNo ?? '');
    _ifscController = TextEditingController(text: vendor?.ifscCode ?? '');

    // Add listeners to track changes
    _nameController.addListener(_checkIfDirty);
    _descController.addListener(_checkIfDirty);
    _cuisineController.addListener(_checkIfDirty);
    _locationController.addListener(_checkIfDirty);
    _pincodeController.addListener(_checkIfDirty);
    _phoneController.addListener(_checkIfDirty);
    _ownerController.addListener(_checkIfDirty);
    _compTypeController.addListener(_checkIfDirty);
    _regNoController.addListener(_checkIfDirty);
    _aadharController.addListener(_checkIfDirty);
    _panController.addListener(_checkIfDirty);
    _fssaiController.addListener(_checkIfDirty);
    _gstController.addListener(_checkIfDirty);
    _bankNameController.addListener(_checkIfDirty);
    _accHolderController.addListener(_checkIfDirty);
    _accNoController.addListener(_checkIfDirty);
    _ifscController.addListener(_checkIfDirty);
  }

  void _checkIfDirty() {
    if (!_isEditing) return;
    
    final currentVendor = _initialVendor;
    if (currentVendor == null) return;

    final isDirty = _nameController.text.trim() != currentVendor.name ||
        _descController.text.trim() != currentVendor.description ||
        _cuisineController.text.trim() != currentVendor.cuisineType ||
        _locationController.text.trim() != currentVendor.location ||
        _pincodeController.text.trim() != (currentVendor.pincode ?? '') ||
        _phoneController.text.trim() != currentVendor.phone ||
        _ownerController.text.trim() != (currentVendor.ownerName ?? '') ||
        _compTypeController.text.trim() != (currentVendor.companyType ?? '') ||
        _regNoController.text.trim() != (currentVendor.companyRegNo ?? '') ||
        _aadharController.text.trim() != (currentVendor.ownerAadharNo ?? '') ||
        _panController.text.trim() != (currentVendor.panCardNo ?? '') ||
        _fssaiController.text.trim() != (currentVendor.fssaiLicense ?? '') ||
        _gstController.text.trim() != (currentVendor.gstNumber ?? '') ||
        _bankNameController.text.trim() != (currentVendor.bankName ?? '') ||
        _accHolderController.text.trim() != (currentVendor.accountHolderName ?? '') ||
        _accNoController.text.trim() != (currentVendor.bankAccountNo ?? '') ||
        _ifscController.text.trim() != (currentVendor.ifscCode ?? '');

    if (isDirty != _hasChanges) {
      setState(() => _hasChanges = isDirty);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _cuisineController.dispose();
    _locationController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _ownerController.dispose();
    _compTypeController.dispose();
    _regNoController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _fssaiController.dispose();
    _gstController.dispose();
    _bankNameController.dispose();
    _accHolderController.dispose();
    _accNoController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final currentVendor = ref.read(vendorProvider).value;
    if (currentVendor == null) return;

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final updatedVendor = currentVendor.copyWith(
        name: _nameController.text,
        description: _descController.text,
        cuisineType: _cuisineController.text,
        location: _locationController.text,
        pincode: _pincodeController.text,
        phone: _phoneController.text,
        ownerName: _ownerController.text,
        companyType: _compTypeController.text,
        companyRegNo: _regNoController.text,
        ownerAadharNo: _aadharController.text,
        panCardNo: _panController.text,
        fssaiLicense: _fssaiController.text,
        gstNumber: _gstController.text,
        bankName: _bankNameController.text,
        accountHolderName: _accHolderController.text,
        bankAccountNo: _accNoController.text,
        ifscCode: _ifscController.text,
      );

      await ref.read(vendorProvider.notifier).updateProfile(updatedVendor);
      
      setState(() {
        _isEditing = false;
        _hasChanges = false;
        _initialVendor = updatedVendor;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.brandGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(vendorProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: vendorAsync.when(
        loading: () => const ProfileSkeleton(),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (vendor) {
          if (_initialVendor == null && vendor != null) {
            _initialVendor = vendor;
          }

          if (isDesktop) {
            return _buildWebProfile(context, ref, vendor);
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.white.withOpacity(0.1),
                flexibleSpace: FlexibleSpaceBar(
                  expandedTitleScale: 1.1,
                  titlePadding: const EdgeInsets.only(bottom: 65, left: 20),
                  title: !_isEditing ? Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vendor?.name ?? 'Kitchen Name',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 10, color: AppColors.textSub),
                          const SizedBox(width: 4),
                          Text(
                            vendor?.location ?? 'Location',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ) : Text(
                    'EDITING PROFILE',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AppColors.textMain),
                  ),
                  centerTitle: Theme.of(context).platform == TargetPlatform.iOS,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                        ),
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 60, left: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.restaurant_rounded, color: AppColors.brandGreen, size: 32),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!_isEditing)
                    IconButton(
                      icon: Icon(
                        Theme.of(context).platform == TargetPlatform.iOS 
                          ? CupertinoIcons.pencil_ellipsis_rectangle 
                          : Icons.edit_note_rounded, 
                        color: AppColors.brandGreen, 
                        size: 28
                      ),
                      onPressed: () => setState(() => _isEditing = true),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Theme.of(context).platform == TargetPlatform.iOS 
                          ? CupertinoIcons.xmark_circle_fill 
                          : Icons.close_rounded, 
                        color: AppColors.textSub, 
                        size: 28
                      ),
                      onPressed: () {
                        _initControllers(_initialVendor);
                        setState(() {
                          _isEditing = false;
                          _hasChanges = false;
                        });
                      },
                    ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.brandGreen,
                      indicatorWeight: 3,
                      labelColor: AppColors.textMain,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      unselectedLabelColor: AppColors.textSub,
                      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'KITCHEN'),
                        Tab(text: 'BUSINESS'),
                        Tab(text: 'BANK'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent('kitchen'),
                _buildTabContent('business'),
                _buildTabContent('bank'),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _hasChanges && _isEditing
          ? FloatingActionButton.extended(
              onPressed: _saveProfile,
              backgroundColor: AppColors.brandGreen,
              elevation: 4,
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text(
                'SAVE CHANGES',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            )
          : null,
    );
  }

  Widget _buildWebProfile(BuildContext context, WidgetRef ref, dynamic vendor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Settings',
                        style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your kitchen profile and business legalities',
                        style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSub, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (!_isEditing)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_note_rounded, size: 22),
                      label: Text('EDIT PROFILE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _initControllers(_initialVendor);
                            setState(() {
                              _isEditing = false;
                              _hasChanges = false;
                            });
                          },
                          child: Text('DISCARD', style: GoogleFonts.inter(color: AppColors.textSub, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 24),
                        ElevatedButton.icon(
                          onPressed: _hasChanges ? _saveProfile : null,
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text('SAVE CHANGES', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 64),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.grey[100]!),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 60, offset: const Offset(0, 20))],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: AppColors.brandGreen.withOpacity(0.08),
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: AppColors.brandGreen,
                        unselectedLabelColor: AppColors.textDisabled,
                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1),
                        tabs: const [
                          Tab(text: 'KITCHEN FOUNDATION'),
                          Tab(text: 'BUSINESS COMPLIANCE'),
                          Tab(text: 'BANKING DETAILS'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 700,
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(), // Force use of tab click on web
                        children: [
                          _buildTabContent('kitchen'),
                          _buildTabContent('business'),
                          _buildTabContent('bank'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String type) {
    List<Widget> fields = [];
    if (type == 'kitchen') {
      fields = [
        _buildStandardField('Kitchen Name', _nameController, Icons.storefront_rounded),
        _buildStandardField('Description', _descController, Icons.description_rounded, maxLines: 3),
        _buildStandardField('Cuisine Type', _cuisineController, Icons.restaurant_menu_rounded),
        _buildStandardField('Location', _locationController, Icons.location_on_rounded),
        _buildStandardField('Pincode', _pincodeController, Icons.pin_drop_rounded, isNumber: true),
        _buildStandardField('Phone Number', _phoneController, Icons.phone_rounded, isNumber: true),
      ];
    } else if (type == 'business') {
      fields = [
        _buildStandardField('Owner Name', _ownerController, Icons.person_rounded),
        _buildStandardField('Company Type', _compTypeController, Icons.business_rounded),
        _buildStandardField('Registration No', _regNoController, Icons.app_registration_rounded),
        _buildStandardField('Aadhar Number', _aadharController, Icons.badge_rounded, isNumber: true),
        _buildStandardField('PAN Number', _panController, Icons.credit_card_rounded),
        _buildStandardField('FSSAI License', _fssaiController, Icons.verified_user_rounded),
        _buildStandardField('GST Number', _gstController, Icons.account_balance_rounded),
      ];
    } else if (type == 'bank') {
      fields = [
        _buildStandardField('Bank Name', _bankNameController, Icons.account_balance_rounded),
        _buildStandardField('Account Holder', _accHolderController, Icons.person_outline_rounded),
        _buildStandardField('Account Number', _accNoController, Icons.numbers_rounded, isNumber: true),
        _buildStandardField('IFSC Code', _ifscController, Icons.code_rounded),
      ];
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        _buildSection(type, fields),
      ],
    );
  }

  Widget _buildSection(String type, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.toUpperCase() + ' DETAILS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandGreen,
                  letterSpacing: 1,
                ),
              ),
              if (type == 'business' && !_isEditing)
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.brandGreen, size: 12),
                        const SizedBox(width: 4),
                        Text('REPORTS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandGreen)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE0E0E0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02), 
                blurRadius: 20, 
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i < fields.length - 1) const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        if (type == 'kitchen') ...[
          const SizedBox(height: 24),
          _buildLogoutButton(context, ref),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStandardField(
    String label, 
    TextEditingController controller, 
    IconData icon,
    {bool isNumber = false, int maxLines = 1}
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isDesktop ? AppColors.textDisabled : AppColors.textSub),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDesktop ? AppColors.textDisabled : AppColors.textSub,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: _isEditing,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _isEditing ? AppColors.textMain : AppColors.textMain.withOpacity(0.8),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showLogoutDialog(context, ref),
        icon: const Icon(Icons.logout, color: AppColors.errorRed, size: 18),
        label: Text('LOGOUT ACCOUNT', style: GoogleFonts.inter(color: AppColors.errorRed, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: Color(0xFFFFEEEE)),
          backgroundColor: const Color(0xFFFFF8F8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('LOGOUT?', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          content: Text('You will need to sign in again to manage your kitchen.', style: GoogleFonts.inter()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text('Stay', style: GoogleFonts.inter(color: CupertinoColors.systemBlue)),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                ref.read(vendorProvider.notifier).logout();
                Navigator.pop(context);
              },
              child: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('LOGOUT?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Text('You will need to sign in again to manage your kitchen.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSub)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('STAY', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w800))
            ),
            TextButton(
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                ref.read(vendorProvider.notifier).logout();
                Navigator.pop(context);
              },
              child: Text('LOGOUT', style: GoogleFonts.inter(color: AppColors.errorRed, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }
  }
}
