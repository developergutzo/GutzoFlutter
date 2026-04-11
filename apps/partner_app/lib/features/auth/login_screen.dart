import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/models/vendor.dart';
import 'vendor_provider.dart';
import '../../shared/widgets/adaptive_wrapper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final vendorData = await ref.read(authServiceProvider).partnerLogin(email, password);
      if (vendorData != null) {
        // Success! Set vendor data directly from login response
        final vendor = Vendor.fromJson(vendorData);
        await ref.read(vendorProvider.notifier).setVendor(vendor);
        
        if (mounted) {
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email or password. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AdaptiveWrapper(
        isAuth: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandGreen.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Partner Portal',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Login to manage your kitchen and orders.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSub,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Email Address',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      placeholder: 'kitchen@gutzo.in',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.mail, size: 20, color: AppColors.brandGreen)),
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                  : TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. kitchen@gutzo.in',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.brandGreen),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                const SizedBox(height: 24),
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoTextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      placeholder: '••••••••',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.lock, size: 20, color: AppColors.brandGreen)),
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(_obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                  : TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.brandGreen),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Forgot password logic
                    },
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.brandGreen, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton.filled(
                        padding: const EdgeInsets.all(18),
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text('LOGIN', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      )
                    : ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('LOGIN', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'By logging in, you agree to Gutzo\'s Terms & Conditions',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
