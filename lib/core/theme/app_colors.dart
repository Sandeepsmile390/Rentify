import 'package:flutter/material.dart';

/// Rentify design system colors.
/// Adaptive between Light (default) and Dark Obsidian modes.
class AppColors {
  AppColors._();

  /// Set dynamically by ThemeModeNotifier.
  static bool isDark = false;

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
  /// Primary text — dark in light mode, crisp white in dark mode
  static Color get ink => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);

  /// Secondary text
  static Color get inkLight => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151);
  static Color get inkSecondary => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151);

  /// Tertiary / caption text
  static Color get inkMuted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

  /// Placeholder / disabled text
  static Color get inkDisabled => isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);

  // ── Backgrounds ──────────────────────────────────────────────────
  /// Page / scaffold background
  static Color get canvas => isDark ? const Color(0xFF090D16) : const Color(0xFFF8F9FA);

  /// Card / surface background
  static Color get surface => isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);

  /// Subtle inset / table row alternate
  static Color get surfaceVariant => isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6);

  /// Dividers and card borders
  static Color get border => isDark ? const Color(0xFF2A3649) : const Color(0xFFE5E7EB);

  // ── Semantic — Success / Paid ────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static Color get successBg => isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4);
  static Color get successBorder => isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0);

  // ── Semantic — Error / Dues ──────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFEF4444);
  static Color get errorBg => isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
  static Color get errorBorder => isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);

  // ── Semantic — Action / Blue ─────────────────────────────────────
  static const Color action = Color(0xFF2563EB);
  static const Color actionLight = Color(0xFF3B82F6);
  static Color get actionBg => isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
  static Color get actionBorder => isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);

  // ── Semantic — Warning / Amber ───────────────────────────────────
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFF59E0B);
  static Color get warningBg => isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
  static Color get warningBorder => isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);

  // ── Financial display ─────────────────────────────────────────────
  /// Positive/collected amounts
  static const Color amountPositive = Color(0xFF16A34A);

  /// Outstanding / dues
  static const Color amountDue = Color(0xFFDC2626);

  /// Neutral amount (paid, settled)
  static Color get amountNeutral => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151);
}
