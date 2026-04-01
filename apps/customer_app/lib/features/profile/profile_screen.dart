import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import '../orders/orders_history_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
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
                    'Log Out?',
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
                'Are you sure you want to log out?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'No',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSub,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.errorBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authServiceProvider).signOut();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        'Yes',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorRed,
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

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    
    if (pickedFile == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final uploadUrl = await ref.read(nodeApiServiceProvider).uploadAvatar(pickedFile.path, user.phone);
      if (uploadUrl != null) {
        await ref.read(authServiceProvider).updateAvatar(uploadUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Profile Photo',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.textMain),
                ),
                title: Text('Take a photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.textMain),
                ),
                title: Text('Choose from gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              if (ref.read(currentUserProvider)?.avatarUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: Text('Remove photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(authServiceProvider).updateAvatar('');
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    final String initials = user?.initials ?? '?';
    final String displayName = (user != null && user.name.isNotEmpty) ? user.name : 'Guest User';
    final String displayPhone = user != null ? '+91 ${user.phone}' : '';
    final String displayEmail = (user != null && user.email.isNotEmpty) ? user.email : '';
    final String? avatarUrl = user?.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textMain,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMain),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            elevation: 4,
            offset: const Offset(0, 42),
            onSelected: (val) {
              if (val == 'logout') {
                _showLogoutDialog(context, ref);
              } else if (val == 'settings') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => _SettingsScreen()),
                );
              } else if (val == 'edit') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => _EditProfileScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              _popupItem(Icons.edit_outlined, 'Edit profile', 'edit'),
              _popupItem(Icons.settings_outlined, 'Settings', 'settings'),
              _popupItem(Icons.logout, 'Logout', 'logout'),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // Avatar
            GestureDetector(
              onTap: _showImageSourceActionSheet,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.brandGreen, width: 2),
                      image: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandGreen,
                              ),
                            ),
                          )
                        : null,
                  ),
                  
                  if (_isUploading)
                     Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              displayName,
              style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),

            if (displayPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  displayPhone,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDisabled),
                ),
              ),

            if (displayEmail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  displayEmail,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDisabled),
                ),
              ),

            const SizedBox(height: 36),

            // Menu items
            _card([
              _row(context, Icons.receipt_long_outlined, 'My Orders', () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const OrdersHistoryScreen()));
              }),
              _divider(),
              _row(context, Icons.help_outline, 'Help & Support', () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const _HelpSupportScreen()));
              }),
              _divider(),
              _row(context, Icons.info_outline, 'About Gutzo', () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const _AboutScreen()));
              }),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textMain),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMain)),
      ]),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 60, endIndent: 0, color: Color(0xFFF0F0F0));

  Widget _row(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF9E9E9E), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Screen (accessed via 3-dot menu) ────────────────────────────────

class _SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _settingRow(Icons.notifications_outlined, 'Notifications', () {
                    Navigator.push(context, CupertinoPageRoute(builder: (_) => const _NotificationsScreen()));
                  }),
                  const Divider(height: 1, indent: 52, color: Color(0xFFF0F0F0)),
                  _settingRow(Icons.lock_outline, 'Privacy', () {
                    Navigator.push(context, CupertinoPageRoute(builder: (_) => const _PrivacyScreen()));
                  }),
                  const Divider(height: 1, indent: 52, color: Color(0xFFF0F0F0)),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showDeleteDialog(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('Delete Account',
                                style: GoogleFonts.poppins(
                                    fontSize: 15, fontWeight: FontWeight.w500, color: Colors.red)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.red, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF9E9E9E), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMain)),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
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
                    'Delete Account?',
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
                'This will permanently delete your account and all data. This action cannot be undone.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F0F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authServiceProvider).signOut();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        'Delete',
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
}

// ─── Edit Profile Screen ───────────────────────────────────────────────────────

class _EditProfileScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<_EditProfileScreen> {
  // Which field is currently being edited: null | 'name' | 'email'
  String? _editing;
  bool _saving = false;
  String? _emailError;

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEdit(String field) {
    final user = ref.read(currentUserProvider);
    if (field == 'name') _nameController.text = user?.name ?? '';
    if (field == 'email') _emailController.text = user?.email ?? '';
    setState(() {
      _editing = field;
      _emailError = null;
    });
  }

  void _cancelEdit() {
    final user = ref.read(currentUserProvider);
    if (_editing == 'name') _nameController.text = user?.name ?? '';
    if (_editing == 'email') _emailController.text = user?.email ?? '';
    setState(() {
      _editing = null;
      _emailError = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _updateField(String field) async {
    final user = ref.read(currentUserProvider);
    String name = user?.name ?? '';
    String email = user?.email ?? '';

    if (field == 'name') {
      name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name cannot be empty')),
        );
        return;
      }
    } else if (field == 'email') {
      email = _emailController.text.trim();
      if (email.isNotEmpty && !_isValidEmail(email)) {
        setState(() => _emailError = 'Please enter a valid email address');
        return;
      }
    }

    setState(() => _saving = true);
    await ref.read(authServiceProvider).updateProfile(name: name, email: email);
    setState(() { _saving = false; _editing = null; _emailError = null; });
    FocusScope.of(context).unfocus();
  }

  bool _isValidEmail(String email) {
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return false;
    }
    final parts = email.split('@');
    if (parts.length == 2) {
      final domain = parts[1].toLowerCase();
      
      // Exact known typo matches (transpositions/additions)
      const knownTypos = [
        'gamil.com', 'gmial.com', 'gmaik.com', 'gmqil.com', 'gmaill.com',
        'gmaiil.com', 'gmao.com', 'gmaio.com',
        'gmail.co', 'gmail.con', 'gmail.cm', 'gmail.om', 'gmail.cop', 'gmail.com.',
        'gmail.in', 'gmail.co.in'
      ];
      if (knownTypos.contains(domain)) return false;

      // Reject domains that are obviously missing letters from 'gmail'
      // e.g., ending in .com/.co and prefix being a subset of 'gmail'
      final domainParts = domain.split('.');
      if (domainParts.length >= 2) {
        final prefix = domainParts[0];
        final tld = domainParts.sublist(1).join('.');
        
        if (tld == 'com' || tld == 'co' || tld == 'in') {
          // Check if prefix is a deletion-based typo of "gmail" (matches g?m?a?i?l?)
          if (RegExp(r'^g?m?a?i?l?$').hasMatch(prefix) && prefix.isNotEmpty) {
            // Explicitly allow 'mail.com' and 'gmail.com', reject all others (e.g., il.com, l.co, gil.com)
            if (prefix != 'mail' && prefix != 'gmail') {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── WhatsApp Number (always read-only) ──
            _fieldLabel('WhatsApp Number'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '+91 ${user?.phone ?? ''}',
                      style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textDisabled),
                    ),
                  ),
                  const Icon(Icons.verified, color: AppColors.brandGreen, size: 16),
                  const SizedBox(width: 4),
                  Text('Verified',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.brandGreen, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Full Name ──
            _fieldLabel('Full Name'),
            const SizedBox(height: 6),
            _editableField(
              field: 'name',
              controller: _nameController,
              display: user?.name ?? '',
              hint: 'Enter your name',
            ),

            const SizedBox(height: 24),

            // ── Email ──
            _fieldLabel('Email Address'),
            const SizedBox(height: 6),
            _editableField(
              field: 'email',
              controller: _emailController,
              display: user?.email ?? '',
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label,
        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDisabled, fontWeight: FontWeight.w500));
  }

  Widget _editableField({
    required String field,
    required TextEditingController controller,
    required String display,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
  }) {
    final isEditing = _editing == field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field row
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null && isEditing ? Colors.red : (isEditing ? AppColors.brandGreen : const Color(0xFFE8E8E8)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: keyboardType,
                        style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textMain),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: GoogleFonts.poppins(color: AppColors.textDisabled),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Text(
                          display.isNotEmpty ? display : hint,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: display.isNotEmpty ? AppColors.textMain : AppColors.textDisabled,
                          ),
                        ),
                      ),
              ),
              // Edit icon (only shown when not editing)
              if (!isEditing)
                GestureDetector(
                  onTap: () => _startEdit(field),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textDisabled),
                  ),
                ),
            ],
          ),
        ),

        // Error label
        if (errorText != null && isEditing) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(errorText, style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
          ),
        ],

        // Update / Cancel buttons (shown only when editing this field)
        if (isEditing) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              // Update button
              Expanded(
                child: GestureDetector(
                  onTap: _saving ? null : () => _updateField(field),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen))
                        : Text('Update',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brandGreen)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Cancel button
              Expanded(
                child: GestureDetector(
                  onTap: _cancelEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDisabled)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  const _NotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const Icon(Icons.chat_bubble_outline, color: AppColors.textMain, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WhatsApp Updates', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                        const SizedBox(height: 2),
                        Text('Required for critical order drops', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const CupertinoSwitch(value: true, onChanged: null, activeColor: AppColors.brandGreen),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                   const Icon(Icons.phonelink_ring_outlined, color: AppColors.textMain, size: 32),
                   const SizedBox(height: 12),
                   Text('Seamless Experience', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.brandGreen)),
                   const SizedBox(height: 16),
                   _featureRow(Icons.bolt, 'Live Order Tracking'),
                   const SizedBox(height: 10),
                   _featureRow(Icons.receipt_long_outlined, 'Instant Secure Invoices'),
                   const SizedBox(height: 10),
                   _featureRow(Icons.block, 'No Intrusive Push Alerts'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.textMain),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMain, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PrivacyScreen extends StatelessWidget {
  const _PrivacyScreen();

  @override
  Widget build(BuildContext context) {
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
          'Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: March 2024',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            _privacySection('1. Introduction', 'We, Gutzo ("Gutzo," "we," "us," or "our") are committed to protecting our customers\' personal data. This privacy policy describes the types of personal data we collect on the platform (Gutzo website, mobile and other software applications, and individual establishments or partners) and processed in relation to the services offered by us.'),
            _privacySection('2. Collection of Your Information', 'We collect your personal data when you use our Platform, services or otherwise interact with us. This includes:\n\n• Information You Provide: Name, email address, phone number, and location.\n• Automatic Collection: Device info, IP address, browser type, and system logs.\n• Cookies: To improve browsing activities and preferences.'),
            _privacySection('3. Usage of Your Information', 'We use your personal data to:\n\n• Provide and improve our services.\n• Send order notifications and updates.\n• Personalize your experience.\n• Prevent fraud and ensure security.'),
            _privacySection('4. Sharing of Your Information', 'We share info with our partners (kitchens/delivery) and service providers for operations. We only disclose information when required by law or for safety.'),
            _privacySection('5. Security Precautions', 'We use industry-standard measures to protect your data. However, remember no internet transmission is 100% secure.'),
            _privacySection('6. Data Deletion and Retention', '• Account Deletion: Accessible via profile settings. Affects all associated data.\n• Retention: Data is kept only as long as needed for legal or business purposes.'),
            _privacySection('7. Your Rights', 'Access, rectify, or update your data directly through the Platform settings.'),
            _privacySection('8. Consent', 'By using Gutzo, you consent to this policy and authorize us to contact you for core service updates via SMS, WhatsApp, or calls.'),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Text('Grievance Officer', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                  const SizedBox(height: 4),
                  Text('Mahelakshmi Sundaram', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMain)),
                  const SizedBox(height: 2),
                  Text('Designation: Founder & Proprietor', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSub)),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _privacySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMain)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.poppins(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.6)),
        ],
      ),
    );
  }
}

class _HelpSupportScreen extends StatelessWidget {
  const _HelpSupportScreen();

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textMain),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "How can we help you today?",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Our team is here to ensure you have the best experience with Gutzo.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSub,
              ),
            ),
            const SizedBox(height: 32),
            
            // Direct Contact Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_outlined,
                      color: AppColors.brandGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Speak with us directly",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Available for immediate assistance, feedback, and research inquiries.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSub,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _makePhoneCall('+918903589068'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "+91 89035 89068",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
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
          'About Gutzo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textMain),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/gutzo_premium_badge_illustration.png',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 24),
            Text(
              "Feels Lighter",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.brandGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Delicious eating made simple and local.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textMain,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            _aboutSection(
              "Who we are", 
              "Gutzo was born because finding clean, honest food felt difficult every single day. We are a small team dedicated to making daily eating feel easy and natural, not stressful."
            ),
            _aboutSection(
              "Our Solution", 
              "We provide a simple platform for better food choices with trusted restaurants, clear information, and zero confusion. We believe good food should fit your daily life effortlessly."
            ),
            _aboutSection(
              "Our Philosophy", 
              "Local, honest, and made for people who want to take care of themselves. We are starting our journey in Coimbatore, growing one city at a time with a focus on quality and user trust."
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    "Get in touch",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "manage.gutzo@gmail.com",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text(
              "Made with ❤️ for Coimbatore",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _aboutSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSub,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}


