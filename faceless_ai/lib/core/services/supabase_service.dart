import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Faceless AI — Supabase Service
/// Handles initialization, auth, and profile management
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call in main() before runApp
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  // ── Auth Helpers ──

  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  /// Sign up with email/password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (displayName != null) 'display_name': displayName,
      },
    );

    // Create profile row
    if (response.user != null) {
      await _createProfile(response.user!, displayName);
    }

    return response;
  }

  /// Sign in with email/password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google OAuth
  static Future<bool> signInWithGoogle() async {
    final result = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.facelessai://login-callback/',
    );
    return result;
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Create user profile after signup
  static Future<void> _createProfile(User user, String? displayName) async {
    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'display_name':
            displayName ?? user.userMetadata?['full_name'] ?? 'User',
        'avatar_url': user.userMetadata?['avatar_url'],
        'credits_remaining': AppConstants.freeVideoCredits,
        'plan': 'free',
      });
    } catch (_) {
      // Profile might already exist (e.g., from a trigger)
    }
  }

  // ── Profile ──

  static Future<Map<String, dynamic>?> getProfile() async {
    if (userId == null) return null;
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId!)
        .maybeSingle();
    return response;
  }

  static Future<void> decrementCredits() async {
    if (userId == null) return;
    await client.rpc('decrement_credits', params: {'user_id_param': userId});
  }
}
