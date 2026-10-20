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
        primary: const Color(0xFF38BDF8),
        onPrimary: const Color(0xFF0A0F1D),
        primaryContainer: const Color(0xFF111E38),
        onPrimaryContainer: const Color(0xFFBAE6FD),
        secondary: const Color(0xFF38BDF8),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFF1E293B),
        onSecondaryContainer: Colors.white,
        tertiary: const Color(0xFF34D399),
        onTertiary: const Color(0xFF063726),
        tertiaryContainer: const Color(0xFF063726),
        onTertiaryContainer: const Color(0xFF6EE7B7),
        error: const Color(0xFFF87171),
        onError: Colors.white,
        errorContainer: const Color(0xFF381215),
        onErrorContainer: const Color(0xFFFECDD3),
        surface: const Color(0xFF131B2E),
        onSurface: const Color(0xFFFFFFFF),
        surfaceContainerHighest: const Color(0xFF1C263D),
        onSurfaceVariant: const Color(0xFF94A3B8),
        outline: const Color(0xFF26354E),
        outlineVariant: const Color(0xFF26354E),
        scrim: Colors.black87,
        inverseSurface: const Color(0xFFFFFFFF),
        onInverseSurface: const Color(0xFF0F172A),
        inversePrimary: AppColors.action,
        shadow: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0F1D),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: AppTextStyles.display.copyWith(color: const Color(0xFFFFFFFF)),
        headlineLarge: AppTextStyles.h1.copyWith(color: const Color(0xFFFFFFFF)),
        headlineMedium: AppTextStyles.h2.copyWith(color: const Color(0xFFFFFFFF)),
        headlineSmall: AppTextStyles.h3.copyWith(color: const Color(0xFFFFFFFF)),
        bodyLarge: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFFE2E8F0)),
        bodyMedium: AppTextStyles.bodyRegular.copyWith(color: const Color(0xFFCBD5E1)),
        bodySmall: AppTextStyles.caption.copyWith(color: const Color(0xFF94A3B8)),
        labelLarge: AppTextStyles.button.copyWith(color: Colors.white),
        labelMedium: AppTextStyles.buttonSmall.copyWith(color: Colors.white),
        labelSmall: AppTextStyles.captionBold.copyWith(color: const Color(0xFFE2E8F0)),
      ),
    );

    return _buildTheme(base, isDark: true);
  }

  static ThemeData _buildTheme(ThemeData base, {required bool isDark}) {
    final surfaceColor = isDark ? const Color(0xFF131B2E) : const Color(0xFFFFFFFF);
    final elevatedColor = isDark ? const Color(0xFF182238) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF26354E) : const Color(0xFFE5E7EB);
    final inkColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
    final inkSecondaryColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151);
    final inkMutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final primaryAccent = isDark ? const Color(0xFF38BDF8) : AppColors.action;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: inkColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
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
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevatedColor,
        modalBackgroundColor: elevatedColor,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevatedColor,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        titleTextStyle: AppTextStyles.h2.copyWith(color: inkColor),
        contentTextStyle: AppTextStyles.bodyRegular.copyWith(color: inkSecondaryColor),
        elevation: 6,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevatedColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: _formRadius,
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        textStyle: AppTextStyles.bodyRegular.copyWith(color: inkColor),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryAccent,
        unselectedLabelColor: inkMutedColor,
        indicatorColor: primaryAccent,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: borderColor,
        labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.bodyMedium,
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
          foregroundColor: primaryAccent,
          side: BorderSide(color: primaryAccent, width: 1.2),
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: _formRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF182238) : surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.inputHint.copyWith(color: inkMutedColor),
        labelStyle: AppTextStyles.inputLabel.copyWith(color: inkSecondaryColor),
        errorStyle: AppTextStyles.inputError.copyWith(color: isDark ? const Color(0xFFF87171) : AppColors.error),
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
          borderSide: BorderSide(color: primaryAccent, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: isDark ? const Color(0xFFF87171) : AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: isDark ? const Color(0xFFF87171) : AppColors.error, width: 2.0),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _formRadius,
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1C263D) : const Color(0xFFF3F4F6),
        shape: const RoundedRectangleBorder(borderRadius: _chipRadius),
        labelStyle: AppTextStyles.captionBold.copyWith(color: inkColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(color: borderColor, width: 0.8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryAccent,
        unselectedItemColor: inkMutedColor,
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.navy,
        selectedIconTheme: IconThemeData(color: primaryAccent, size: 22),
        unselectedIconTheme: IconThemeData(color: inkMutedColor, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: primaryAccent,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF111827),
        contentTextStyle: AppTextStyles.bodyRegular.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: _formRadius,
          side: BorderSide(color: borderColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1.0,
        space: 1.0,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        iconColor: isDark ? const Color(0xFF94A3B8) : inkMutedColor,
        titleTextStyle: AppTextStyles.bodyMedium.copyWith(color: inkColor, fontWeight: FontWeight.w600),
        subtitleTextStyle: AppTextStyles.caption.copyWith(color: inkMutedColor),
        minLeadingWidth: 24,
        minTileHeight: 56,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (isDark ? const Color(0xFF38BDF8) : AppColors.action) : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF0C4A6E) : AppColors.actionBg)
              : borderColor,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryAccent,
        linearTrackColor: isDark ? const Color(0xFF1E293B) : AppColors.actionBg,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? const Color(0xFF2563EB) : AppColors.action,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
