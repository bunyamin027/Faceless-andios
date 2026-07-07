import 'package:flutter/material.dart';

/// Faceless AI — Premium dark color palette
/// Designed for a cinematic, high-end feel
class AppColors {
  AppColors._();

  // ── Background Layers ──
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A28);
  static const Color surfaceElevated = Color(0xFF222236);

  // ── Glass Effect ──
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassBackground = Color(0x0DFFFFFF);
  static const Color glassSurface = Color(0x08FFFFFF);

  // ── Primary Gradient (Electric Violet → Cyan) ──
  static const Color primaryStart = Color(0xFF7C3AED);
  static const Color primaryEnd = Color(0xFF06B6D4);
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF8B5CF6);

  // ── Accent (Hot Pink for CTAs) ──
  static const Color accent = Color(0xFFEC4899);
  static const Color accentLight = Color(0xFFF472B6);

  // ── Success / Error / Warning ──
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // ── Status Badge Colors ──
  static const Color statusDraft = Color(0xFF64748B);
  static const Color statusProcessing = Color(0xFFF59E0B);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusFailed = Color(0xFFEF4444);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryStart, primaryEnd],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryStart],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, background],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    colors: [
      Color(0xFF1A1A28),
      Color(0xFF222236),
      Color(0xFF1A1A28),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ── Glow Effects ──
  static List<BoxShadow> primaryGlow({double opacity = 0.3}) => [
        BoxShadow(
          color: primaryStart.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> accentGlow({double opacity = 0.3}) => [
        BoxShadow(
          color: accent.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ];
}
