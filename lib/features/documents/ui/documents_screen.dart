import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, this.tenancyId});
  final String? tenancyId;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: Text('Documents', style: AppTextStyles.h2)),
    body: const Center(child: Text('Documents — Phase 3')));
}
