import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Central Material 3 theme for Rentify.
/// Supports both pristine Light Mode and deep Obsidian Dark Mode.
class AppTheme {
  AppTheme._();

  static const _cardRadius = BorderRadius.all(Radius.circular(12));
  static const _formRadius = BorderRadius.all(Radius.circular(10));
  static const _chipRadius = BorderRadius.all(Radius.circular(20));

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
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

    return _buildTheme(base, isDark: false);
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.actionLight,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF172554),
        onPrimaryContainer: const Color(0xFF93C5FD),
        secondary: const Color(0xFF334155),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFF1E293B),
        onSecondaryContainer: Colors.white,
        tertiary: AppColors.successLight,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFF064E3B),
        onTertiaryContainer: const Color(0xFF6EE7B7),
        error: AppColors.errorLight,
        onError: Colors.white,
        errorContainer: const Color(0xFF450A0A),
        onErrorContainer: const Color(0xFFFCA5A5),
        surface: const Color(0xFF111827),
        onSurface: const Color(0xFFF8FAFC),
        surfaceContainerHighest: const Color(0xFF1E293B),
        onSurfaceVariant: const Color(0xFF94A3B8),
        outline: const Color(0xFF2A3649),
        outlineVariant: const Color(0xFF2A3649),
        scrim: Colors.black87,
        inverseSurface: const Color(0xFFF8FAFC),
        onInverseSurface: const Color(0xFF0F172A),
        inversePrimary: AppColors.action,
        shadow: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: const Color(0xFF090D16),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: AppTextStyles.display.copyWith(color: const Color(0xFFF8FAFC)),
        headlineLarge: AppTextStyles.h1.copyWith(color: const Color(0xFFF8FAFC)),
        headlineMedium: AppTextStyles.h2.copyWith(color: const Color(0xFFF8FAFC)),
        headlineSmall: AppTextStyles.h3.copyWith(color: const Color(0xFFF8FAFC)),
        bodyLarge: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFFE2E8F0)),
        bodyMedium: AppTextStyles.bodyRegular.copyWith(color: const Color(0xFFCBD5E1)),
        bodySmall: AppTextStyles.caption.copyWith(color: const Color(0xFF94A3B8)),
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.buttonSmall,
        labelSmall: AppTextStyles.captionBold.copyWith(color: const Color(0xFFCBD5E1)),
      ),
    );

    return _buildTheme(base, isDark: true);
  }

  static ThemeData _buildTheme(ThemeData base, {required bool isDark}) {
    final surfaceColor = isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF2A3649) : const Color(0xFFE5E7EB);
    final inkColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final inkMutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: inkColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: borderColor,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h2.copyWith(color: inkColor),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: inkColor, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: borderColor,
          disabledForegroundColor: inkMutedColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.actionLight : AppColors.action,
          side: BorderSide(color: isDark ? AppColors.actionLight : AppColors.action),
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.actionLight : AppColors.action,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.inputHint.copyWith(color: inkMutedColor),
        labelStyle: AppTextStyles.inputLabel.copyWith(color: inkColor),
        errorStyle: AppTextStyles.inputError,
        border: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: isDark ? AppColors.actionLight : AppColors.action, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: _chipRadius),
        labelStyle: AppTextStyles.captionBold.copyWith(color: inkColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: isDark ? AppColors.actionLight : AppColors.action,
        unselectedItemColor: inkMutedColor,
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.navy,
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 22),
        unselectedIconTheme: IconThemeData(color: inkMutedColor, size: 22),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: inkMutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        titleTextStyle: AppTextStyles.h2.copyWith(color: inkColor),
        contentTextStyle: AppTextStyles.bodyRegular.copyWith(color: inkColor),
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF111827),
        contentTextStyle: AppTextStyles.bodyRegular.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        iconColor: inkMutedColor,
        titleTextStyle: AppTextStyles.bodyMedium.copyWith(color: inkColor),
        subtitleTextStyle: AppTextStyles.caption.copyWith(color: inkMutedColor),
        minLeadingWidth: 24,
        minTileHeight: 56,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.action : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF1D4ED8) : AppColors.actionBg)
              : borderColor,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.actionLight : AppColors.action,
        linearTrackColor: isDark ? const Color(0xFF1E293B) : AppColors.actionBg,
      ),
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
