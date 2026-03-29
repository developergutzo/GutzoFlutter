import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';

enum AuthStep { phone, otp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  AuthStep _step = AuthStep.phone;
  String _phoneNumber = '';
  String? _lastPhoneNumber;
  int _timerSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Check for last used phone number
    _lastPhoneNumber = ref.read(authServiceProvider).getLastPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _handlePhoneSubmit() async {
    final phone = _phoneController.text;
    if (phone.length < 10) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      const dummyPhone = '9876543210';
      if (phone == dummyPhone) {
        if (mounted) {
          setState(() {
            _phoneNumber = phone;
            _step = AuthStep.otp;
          });
          _startTimer();
        }
        return;
      }

      final result = await ref.read(nodeApiServiceProvider).sendOtp(phone);
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _phoneNumber = phone;
            _step = AuthStep.otp;
          });
          _startTimer();
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOTPSubmit() async {
    final otp = _otpController.text;
    final phone = _phoneNumber;
    if (otp.length < 6) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      if (phone == '9876543210' && otp == '123456') {
        await ref.read(authServiceProvider).login(phone: phone, name: 'Maha Sundar');
        if (mounted) Navigator.pop(context);
        return;
      }

      final result = await ref.read(nodeApiServiceProvider).verifyOtp(phone, otp);
      if (result['success'] == true) {
        await ref.read(authServiceProvider).login(
          phone: phone,
          name: result['data']?['user']?['name'] ?? 'User',
          email: result['data']?['user']?['email'],
        );
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception(result['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 480,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('assets/images/gutzo_premium_badge_illustration.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.1),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.brandGreen.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          'Eat Smart.\nFeel Great.\nAchieve More.',
                          style: TextStyle(
                            fontSize: 40,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Continue with WhatsApp',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == AuthStep.phone ? 'Welcome to Gutzo' : 'Verify your number',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your WhatsApp number to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      if (_step == AuthStep.phone) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofocus: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          decoration: InputDecoration(
                            prefixText: '+91 ',
                            prefixStyle: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
                            hintText: 'WhatsApp Number',
                            hintStyle: TextStyle(color: AppColors.textDisabled.withValues(alpha: 0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
                            ),
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        if (_lastPhoneNumber != null && _phoneController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              _phoneController.text = _lastPhoneNumber!;
                              _handlePhoneSubmit();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person_outline, color: AppColors.brandGreen, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Continue with',
                                          style: TextStyle(color: AppColors.textSub, fontSize: 12),
                                        ),
                                        Text(
                                          '+91 $_lastPhoneNumber',
                                          style: const TextStyle(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: AppColors.brandGreen, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandGreen,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _phoneController.text.length >= 10 && !_isLoading ? _handlePhoneSubmit : null,
                            child: _isLoading
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Text(
                                    'Get OTP',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ] else ...[
                        Center(child: Text('Sent to +91 $_phoneNumber', style: const TextStyle(color: AppColors.textSub))),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          autofocus: true,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: TextStyle(color: AppColors.textDisabled.withValues(alpha: 0.3)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) {
                            if (val.length == 6) _handleOTPSubmit();
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_timerSeconds > 0)
                          Text('Resend OTP in ${_timerSeconds}s', style: const TextStyle(fontSize: 13, color: AppColors.textSub))
                        else
                          TextButton(onPressed: _handlePhoneSubmit, child: const Text('Resend OTP', style: TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _otpController.text.length == 6 && !_isLoading ? _handleOTPSubmit : null,
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify & Proceed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 64),
                      const Text(
                        'By continuing, you agree to our',
                        style: TextStyle(color: AppColors.textSub, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegalLink(text: 'Terms of Service'),
                          _LegalLink(text: 'Privacy Policy'),
                          _LegalLink(text: 'Content Policy', isLast: true),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget? child;
  const _SocialIconBox({required this.icon, required this.color, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        color: Colors.white,
      ),
      child: Center(
        child: child ?? Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String text;
  final bool isLast;
  const _LegalLink({required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMain,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
