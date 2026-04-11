import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart' as model;
import 'node_api_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main() and override');
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final customAuthProvider = NotifierProvider<CustomAuthNotifier, model.User?>(() {
  return CustomAuthNotifier();
});

class CustomAuthNotifier extends Notifier<model.User?> {
  @override
  model.User? build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final authData = prefs.getString('gutzo_auth');
    if (authData == null) return null;
    
    try {
      final Map<String, dynamic> parsed = jsonDecode(authData);
      return model.User(
        id: parsed['id'] ?? '',
        phone: parsed['phone'] ?? '',
        name: parsed['name'] ?? '',
        email: parsed['email'] ?? '',
        avatarUrl: parsed['avatar_url'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(parsed['timestamp'] ?? 0),
      );
    } catch (e) {
      return null;
    }
  }

  void update(model.User? user) {
    state = user;
  }
}

final currentUserProvider = Provider<model.User?>((ref) {
  // Check custom auth first (React style), then fallback to Supabase
  final customUser = ref.watch(customAuthProvider);
  if (customUser != null) return customUser;

  final authState = ref.watch(authStateProvider).value;
  final user = authState?.session?.user;
  
  if (user == null) return null;
  
  return model.User(
    id: user.id,
    phone: user.phone ?? '',
    name: user.userMetadata?['name'] as String? ?? '',
    email: user.email ?? '',
    avatarUrl: user.userMetadata?['avatar_url'] as String?,
    createdAt: DateTime.parse(user.createdAt),
  );
});

class AuthService {
  final Ref _ref;
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;

  AuthService(this._ref, this._supabase, this._prefs);

  Future<void> login({
    required String phone,
    required String name,
    String? email,
  }) async {
    final authData = {
      'phone': phone,
      'name': name,
      'email': email ?? '',
      'verified': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await _prefs.setString('gutzo_auth', jsonEncode(authData));
    await _prefs.setString('last_phone_number', phone);
    
    // Update state immediately for reactivity
    final user = model.User(
      id: '',
      phone: phone,
      name: name,
      email: email ?? '',
      createdAt: DateTime.now(),
    );
    _ref.read(customAuthProvider.notifier).update(user);
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final authData = _prefs.getString('gutzo_auth');
    if (authData == null) return;
    final Map<String, dynamic> parsed = jsonDecode(authData);
    parsed['name'] = name;
    parsed['email'] = email;
    await _prefs.setString('gutzo_auth', jsonEncode(parsed));
    final current = _ref.read(customAuthProvider);
    if (current != null) {
      _ref.read(customAuthProvider.notifier).update(model.User(
        id: current.id,
        phone: current.phone,
        name: name,
        email: email,
        avatarUrl: current.avatarUrl,
        createdAt: current.createdAt,
      ));
    }
  }

  Future<void> updateAvatar(String url) async {
    final authData = _prefs.getString('gutzo_auth');
    if (authData == null) return;
    final Map<String, dynamic> parsed = jsonDecode(authData);
    parsed['avatar_url'] = url;
    await _prefs.setString('gutzo_auth', jsonEncode(parsed));
    final current = _ref.read(customAuthProvider);
    if (current != null) {
      _ref.read(customAuthProvider.notifier).update(model.User(
        id: current.id,
        phone: current.phone,
        name: current.name,
        email: current.email,
        avatarUrl: url,
        createdAt: current.createdAt,
      ));
    }
  }

  Future<bool> sendOtp(String phone) async {
    try {
      final apiService = _ref.read(nodeApiServiceProvider);
      final response = await apiService.sendOtp(phone);
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      final apiService = _ref.read(nodeApiServiceProvider);
      final response = await apiService.verifyOtp(phone, otp);
      if (response['success'] == true) {
        // For partner app, we might not have a "name" yet, or we fetch it later
        final vendorName = response['data']?['vendor']?['name'] ?? 'Partner';
        await login(phone: phone, name: vendorName);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> partnerLogin(String email, String password) async {
    try {
      final apiService = _ref.read(nodeApiServiceProvider);
      final response = await apiService.vendorLogin(email, password);
      if (response['success'] == true) {
        final vendor = response['data']['vendor'];
        final phone = vendor['phone'] ?? '';
        final name = vendor['name'] ?? 'Partner';
        await login(phone: phone, name: name);
        return vendor;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _prefs.remove('gutzo_auth');
    _ref.read(customAuthProvider.notifier).update(null);
  }
  
  User? get currentSupabaseUser => _supabase.auth.currentUser;
  
  String? getLastPhone() => _prefs.getString('last_phone_number');
  
  Future<void> clearLastPhone() async => await _prefs.remove('last_phone_number');
}

final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPrefsProvider);
  return AuthService(ref, supabase, prefs);
});
