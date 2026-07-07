import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Faceless AI — App Constants
class AppConstants {
  AppConstants._();

  // ── App Info ──
  static const String appName = 'Faceless AI';
  static const String appTagline = 'Create viral videos in seconds';

  // ── Supabase ──
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ── Storage Buckets ──
  static const String uploadsBucket = 'uploads';
  static const String rendersBucket = 'renders';
  static const String assetsBucket = 'assets';

  // ── Timeouts ──
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration renderTimeout = Duration(minutes: 5);
  static const Duration uploadTimeout = Duration(minutes: 2);

  // ── Limits ──
  static const int maxUploadSizeMB = 100;
  static const int freeVideoCredits = 3;
  static const int maxSceneDurationSec = 10;
  static const int minSceneDurationSec = 3;
  static const int maxTotalDurationSec = 60;

  // ── Video Specs ──
  static const int videoWidth = 1080;
  static const int videoHeight = 1920;
  static const int videoFps = 30;

  // ── Tones ──
  static const List<String> availableTones = [
    'inspirational',
    'energetic',
    'professional',
    'playful',
    'dramatic',
    'calm',
    'edgy',
    'luxurious',
  ];

  // ── Tone Icons (mapped) ──
  static const Map<String, String> toneEmojis = {
    'inspirational': '✨',
    'energetic': '⚡',
    'professional': '💼',
    'playful': '🎮',
    'dramatic': '🎬',
    'calm': '🌿',
    'edgy': '🔥',
    'luxurious': '💎',
  };
}
