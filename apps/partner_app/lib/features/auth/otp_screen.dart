import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'vendor_provider.dart';
import '../../shared/widgets/adaptive_wrapper.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authServiceProvider).verifyOtp(widget.phone, otp);
      if (success) {
        // Success! Refetch vendor data
        await ref.read(vendorProvider.notifier).fetchVendor();
        if (mounted) {
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OTP. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'VERIFY OTP',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AppColors.textMain),
        ),
        centerTitle: isIOS,
        leading: IconButton(
          icon: Icon(isIOS ? CupertinoIcons.leaf_arrow_circlepath : Icons.eco_rounded, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: AdaptiveWrapper(
        isAuth: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Enter Verification Code',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sent to +91 ${widget.phone}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 48),
                Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoTextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: AppColors.brandGreen,
                      ),
                      placeholder: '000000',
                      placeholderStyle: GoogleFonts.inter(
                        color: AppColors.textDisabled.withOpacity(0.2),
                        letterSpacing: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    )
                  : TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: AppColors.brandGreen,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textDisabled.withOpacity(0.3),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 24),
                      ),
                    ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'RESEND CODE',
                      style: GoogleFonts.inter(
                        color: AppColors.brandGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: isIOS
                    ? CupertinoButton.filled(
                        padding: const EdgeInsets.all(18),
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _isLoading ? null : _handleVerify,
                        child: _isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text('VERIFY', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      )
                    : ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('VERIFY', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
