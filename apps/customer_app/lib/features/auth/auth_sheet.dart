import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/services/auth_service.dart';
import 'package:shared_core/services/node_api_service.dart';
import 'package:shared_core/theme/app_colors.dart';

enum AuthStep { phone, otp, signup }

class AuthStepNotifier extends Notifier<AuthStep> {
  @override
  AuthStep build() => AuthStep.phone;
  void update(AuthStep step) => state = step;
}

final authStepProvider = NotifierProvider<AuthStepNotifier, AuthStep>(AuthStepNotifier.new);

class PhoneNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String phone) => state = phone;
}

final phoneProvider = NotifierProvider<PhoneNotifier, String>(PhoneNotifier.new);

class AuthSheet extends ConsumerStatefulWidget {
  const AuthSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthSheet(),
    );
  }

  @override
  ConsumerState<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<AuthSheet> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = false;
  int _timerSeconds = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
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
    
    setState(() => _isLoading = true);
    try {
      // DUMMY LOGIN logic (mimicking React webapp)
      const dummyPhone = '9876543210';
      if (phone == dummyPhone) {
        ref.read(phoneProvider.notifier).update(phone);
        _startTimer();
        ref.read(authStepProvider.notifier).update(AuthStep.otp);
        return;
      }

      // Real API call
      final result = await ref.read(nodeApiServiceProvider).sendOtp(phone);
      if (result['success'] == true) {
        ref.read(phoneProvider.notifier).update(phone);
        _startTimer();
        ref.read(authStepProvider.notifier).update(AuthStep.otp);
      } else {
        throw Exception(result['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOTPSubmit() async {
    final otp = _otpController.text;
    final phone = ref.read(phoneProvider);
    if (otp.length < 6) return;
    
    setState(() => _isLoading = true);
    try {
      // DUMMY LOGIN check
      if (phone == '9876543210' && otp == '123456') {
        await ref.read(authServiceProvider).login(phone: phone, name: 'PhonePe Test');
        Navigator.pop(context);
        return;
      }

      // Real API call
      final result = await ref.read(nodeApiServiceProvider).verifyOtp(phone, otp);
      if (result['success'] == true) {
        // Success! Persist session
        await ref.read(authServiceProvider).login(
          phone: phone,
          name: result['data']?['user']?['name'] ?? 'User',
          email: result['data']?['user']?['email'],
        );
        Navigator.pop(context);
      } else {
        throw Exception(result['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(authStepProvider);
    final phone = ref.watch(phoneProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                step == AuthStep.phone ? 'Login' : (step == AuthStep.otp ? 'Verify OTP' : 'Sign Up'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (step == AuthStep.phone) ...[
             const Text('Enter your phone number to get started', style: TextStyle(color: AppColors.textSub)),
             const SizedBox(height: 24),
             TextField(
               controller: _phoneController,
               keyboardType: TextInputType.phone,
               decoration: const InputDecoration(
                 labelText: 'Phone Number',
                 hintText: '98765 43210',
                 prefixText: '+91 ',
               ),
               onChanged: (val) => setState(() {}),
             ),
             const SizedBox(height: 24),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _phoneController.text.length >= 10 && !_isLoading ? _handlePhoneSubmit : null,
                 child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Proceed'),
               ),
             ),
          ] else if (step == AuthStep.otp) ...[
             Text('Sent to +91 $phone via WhatsApp', style: const TextStyle(color: AppColors.textSub)),
             const SizedBox(height: 24),
             TextField(
               controller: _otpController,
               keyboardType: TextInputType.number,
               maxLength: 6,
               textAlign: TextAlign.center,
               style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
               decoration: const InputDecoration(
                 labelText: 'Enter 6-digit OTP',
                 counterText: '',
               ),
               onChanged: (val) {
                 if (val.length == 6) _handleOTPSubmit();
               },
             ),
             const SizedBox(height: 16),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 if (_timerSeconds > 0)
                   Text('Resend in ${_timerSeconds}s', style: const TextStyle(color: AppColors.textSub))
                 else
                   TextButton(
                     onPressed: () => _startTimer(),
                     child: const Text('Resend OTP'),
                   ),
                 TextButton(
                    onPressed: () => ref.read(authStepProvider.notifier).update(AuthStep.phone),
                    child: const Text('Change Number'),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _otpController.text.length == 6 && !_isLoading ? _handleOTPSubmit : null,
                 child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify'),
               ),
             ),
          ],
          const SizedBox(height: 16),
          const Text.rich(
            TextSpan(
              text: 'By continuing, I accept the ',
              style: TextStyle(fontSize: 12, color: AppColors.textSub),
              children: [
                TextSpan(text: 'Terms & Conditions', style: TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
                TextSpan(text: ' & '),
                TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
