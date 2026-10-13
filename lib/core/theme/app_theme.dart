import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Central Material 3 theme for Rentify.
/// All screens use this — no ad-hoc color or style overrides.
class AppTheme {
  AppTheme._();

  // ── Shared shape ──────────────────────────────────────────────
  static const _cardRadius = BorderRadius.all(Radius.circular(12));
  static const _formRadius = BorderRadius.all(Radius.circular(10));
  static const _chipRadius = BorderRadius.all(Radius.circular(20));

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.action,
        onPrimary: Colors.white,
        primaryContainer: AppColors.actionBg,
        onPrimaryContainer: AppColors.action,
        secondary: AppColors.navy,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.navyLight,
        onSecondaryContainer: AppColors.navyTextSelected,
        tertiary: AppColors.success,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.successBg,
        onTertiaryContainer: AppColors.success,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorBg,
        onErrorContainer: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.inkMuted,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        scrim: Colors.black54,
        inverseSurface: AppColors.ink,
        onInverseSurface: Colors.white,
        inversePrimary: AppColors.actionLight,
        shadow: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyMedium,
        bodyMedium: AppTextStyles.bodyRegular,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.buttonSmall,
        labelSmall: AppTextStyles.captionBold,
      ),
    );

    return base.copyWith(
      // ── AppBar ─────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h2,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(color: AppColors.inkLight, size: 22),
      ),

      // ── Cards ──────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Elevated Button ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.action,
          side: const BorderSide(color: AppColors.action),
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.action,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),

      // ── Input / Form fields ────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.inputHint,
        labelStyle: AppTextStyles.inputLabel,
        errorStyle: AppTextStyles.inputError,
        border: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.action, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: _chipRadius),
        labelStyle: AppTextStyles.captionBold,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide.none,
      ),

      // ── Bottom Navigation ──────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.action,
        unselectedItemColor: AppColors.inkMuted,
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Navigation Rail ────────────────────────────────────────
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.navy,
        selectedIconTheme: IconThemeData(color: AppColors.navyTextSelected, size: 22),
        unselectedIconTheme: IconThemeData(color: AppColors.navyText, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.navyTextSelected,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.navyText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: Colors.transparent,
        elevation: 0,
      ),

      // ── Dialog ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        titleTextStyle: AppTextStyles.h2,
        contentTextStyle: AppTextStyles.bodyRegular,
        elevation: 4,
      ),

      // ── SnackBar ──────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.bodyRegular.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Divider ───────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── List Tile ─────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        iconColor: AppColors.inkMuted,
        titleTextStyle: AppTextStyles.bodyMedium,
        subtitleTextStyle: AppTextStyles.caption,
        minLeadingWidth: 24,
        minTileHeight: 56,
      ),

      // ── Switch ────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.action : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.actionBg : AppColors.border,
        ),
      ),

      // ── Progress ──────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.action,
        linearTrackColor: AppColors.actionBg,
      ),

      // ── Floating action button ────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
