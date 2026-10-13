import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset password', style: AppTextStyles.h2)),
      backgroundColor: AppColors.canvas,
      body: const Center(child: Text('Password reset — Phase 1')),
    );
  }
}
