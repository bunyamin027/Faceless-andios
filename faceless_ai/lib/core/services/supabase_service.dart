import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
      redirectTo: 'com.facelessai.app://login-callback/',
    );
    return result;
  }

  /// Sign in with Apple (iOS native)
  static Future<AuthResponse> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple Sign In failed: no identity token.');
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Create profile if new user
    if (response.user != null) {
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((n) => n != null && n.isNotEmpty).join(' ');

      await _createProfile(
        response.user!,
        fullName.isNotEmpty ? fullName : null,
      );
    }

    return response;
  }

  /// Generate a random nonce string
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
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
