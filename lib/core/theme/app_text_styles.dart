import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Rentify typography scale.
/// Uses Inter via Google Fonts — matching the Figma specification.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter();

  // ── Display ─────────────────────────────────────────────────────
  /// Logo / product name
  static TextStyle get display => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: AppColors.ink,
        letterSpacing: -0.5,
      );

  // ── Headings ────────────────────────────────────────────────────
  static TextStyle get h1 => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 28 / 20,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get h2 => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: AppColors.ink,
      );

  static TextStyle get h3 => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: AppColors.ink,
      );

  // ── Body ────────────────────────────────────────────────────────
  static TextStyle get bodyRegular => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.inkLight,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: AppColors.ink,
      );

  // ── Caption ─────────────────────────────────────────────────────
  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.inkMuted,
      );

  static TextStyle get captionBold => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        color: AppColors.inkLight,
      );

  // ── Currency / Financial ─────────────────────────────────────────
  static TextStyle get currencyLarge => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: AppColors.ink,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get currencyMedium => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get currencySmall => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Navigation ──────────────────────────────────────────────────
  static TextStyle get navLabel => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );

  // ── Button ──────────────────────────────────────────────────────
  static TextStyle get button => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.1,
      );

  static TextStyle get buttonSmall => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
      );

  // ── Form ────────────────────────────────────────────────────────
  static TextStyle get inputLabel => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        color: AppColors.inkLight,
      );

  static TextStyle get inputText => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.ink,
      );

  static TextStyle get inputHint => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.inkDisabled,
      );

  static TextStyle get inputError => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.error,
      );
}
