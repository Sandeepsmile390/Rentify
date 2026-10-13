import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum StatusChipType { success, error, warning, info, neutral }

/// Coloured status badge used in tenant rows, charge lists, etc.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.type,
    this.semanticLabel,
  });

  final String label;
  final StatusChipType type;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (type) {
      StatusChipType.success => (
          AppColors.successBg,
          AppColors.success,
          AppColors.successBorder,
        ),
      StatusChipType.error => (
          AppColors.errorBg,
          AppColors.error,
          AppColors.errorBorder,
        ),
      StatusChipType.warning => (
          AppColors.warningBg,
          AppColors.warning,
          AppColors.warningBorder,
        ),
      StatusChipType.info => (
          AppColors.actionBg,
          AppColors.action,
          AppColors.actionBorder,
        ),
      StatusChipType.neutral => (
          AppColors.surfaceVariant,
          AppColors.inkMuted,
          AppColors.border,
        ),
    };

    return Semantics(
      label: semanticLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(color: fg),
        ),
      ),
    );
  }
}
