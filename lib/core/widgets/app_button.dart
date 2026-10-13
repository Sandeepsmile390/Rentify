import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Primary action button used throughout Rentify.
/// Supports loading state, disabled state, and optional icon.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.type = AppButtonType.primary,
    this.fullWidth = true,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonType type;
  final bool fullWidth;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: type == AppButtonType.primary
                  ? Colors.white
                  : AppColors.action,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _iconSize),
                const SizedBox(width: 8),
              ],
              Text(label, style: _labelStyle),
            ],
          );

    final height = size == AppButtonSize.small ? 40.0 : 48.0;
    final padding = size == AppButtonSize.small
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    switch (type) {
      case AppButtonType.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: (isLoading || onPressed == null) ? null : onPressed,
            style: ElevatedButton.styleFrom(padding: padding),
            child: child,
          ),
        );
      case AppButtonType.outlined:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: OutlinedButton(
            onPressed: (isLoading || onPressed == null) ? null : onPressed,
            style: OutlinedButton.styleFrom(padding: padding),
            child: child,
          ),
        );
      case AppButtonType.text:
        return TextButton(
          onPressed: (isLoading || onPressed == null) ? null : onPressed,
          style: TextButton.styleFrom(padding: padding),
          child: child,
        );
      case AppButtonType.danger:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: (isLoading || onPressed == null) ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: padding,
            ),
            child: child,
          ),
        );
    }
  }

  double get _iconSize => size == AppButtonSize.small ? 16 : 18;

  TextStyle get _labelStyle {
    final base = size == AppButtonSize.small
        ? AppTextStyles.buttonSmall
        : AppTextStyles.button;
    return base.copyWith(
      color: switch (type) {
        AppButtonType.primary => Colors.white,
        AppButtonType.danger => Colors.white,
        AppButtonType.outlined => AppColors.action,
        AppButtonType.text => AppColors.action,
      },
    );
  }
}

enum AppButtonType { primary, outlined, text, danger }
enum AppButtonSize { medium, small }
