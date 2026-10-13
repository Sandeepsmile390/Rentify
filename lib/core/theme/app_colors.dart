import 'package:flutter/material.dart';

/// Rentify design system colors.
/// Extracted from Figma frame 15 — Developer handoff & design system.
class AppColors {
  AppColors._();

  // ── Brand / structural ──────────────────────────────────────────
  /// Dark navy — sidebar, app bar background
  static const Color navy = Color(0xFF1E2A3A);

  /// Slightly lighter navy — sidebar item hover / selected background
  static const Color navyLight = Color(0xFF263547);

  /// Sidebar item icon / text (unselected)
  static const Color navyText = Color(0xFF8EA3B8);

  /// Sidebar item (selected)
  static const Color navyTextSelected = Color(0xFFFFFFFF);

  // ── Text ────────────────────────────────────────────────────────
  /// Primary text — almost black
  static const Color ink = Color(0xFF111827);

  /// Secondary text — dark grey
  static const Color inkLight = Color(0xFF374151);

  /// Tertiary / caption text
  static const Color inkMuted = Color(0xFF6B7280);

  /// Placeholder / disabled text
  static const Color inkDisabled = Color(0xFF9CA3AF);

  // ── Backgrounds ──────────────────────────────────────────────────
  /// Page / scaffold background
  static const Color canvas = Color(0xFFF8F9FA);

  /// Card / surface background
  static const Color surface = Color(0xFFFFFFFF);

  /// Subtle inset / table row alternate
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  /// Dividers and card borders
  static const Color border = Color(0xFFE5E7EB);

  // ── Semantic — Success / Paid ────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  // ── Semantic — Error / Dues ──────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // ── Semantic — Action / Blue ─────────────────────────────────────
  static const Color action = Color(0xFF2563EB);
  static const Color actionLight = Color(0xFF3B82F6);
  static const Color actionBg = Color(0xFFEFF6FF);
  static const Color actionBorder = Color(0xFFBFDBFE);

  // ── Semantic — Warning / Amber ───────────────────────────────────
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  // ── Financial display ─────────────────────────────────────────────
  /// Positive/collected amounts
  static const Color amountPositive = Color(0xFF16A34A);

  /// Outstanding / dues
  static const Color amountDue = Color(0xFFDC2626);

  /// Neutral amount (paid, settled)
  static const Color amountNeutral = Color(0xFF374151);
}
