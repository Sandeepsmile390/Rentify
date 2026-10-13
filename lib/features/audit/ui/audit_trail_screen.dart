import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
class AuditTrailScreen extends StatelessWidget {
  const AuditTrailScreen({super.key, required this.tenancyId});
  final String tenancyId;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: Text('Audit trail', style: AppTextStyles.h2)),
    body: const Center(child: Text('Audit trail — Phase 5')));
}
