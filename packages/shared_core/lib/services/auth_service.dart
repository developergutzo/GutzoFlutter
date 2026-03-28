import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart' as model;

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

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _prefs.remove('gutzo_auth');
    _ref.read(customAuthProvider.notifier).update(null);
  }
  
  User? get currentSupabaseUser => _supabase.auth.currentUser;
}

final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPrefsProvider);
  return AuthService(ref, supabase, prefs);
});
