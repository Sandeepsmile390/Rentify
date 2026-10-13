import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

/// Figma frame 06 — Secure login & optional biometric
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Check if running in demo mode, testing with demo email, or using placeholder backend
    final isPlaceholderBackend = Env.supabaseUrl.contains('placeholder') ||
        email.toLowerCase() == 'admin@rentify.app';

    if (isPlaceholderBackend) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      ref.read(demoAuthProvider.notifier).loginAsAdmin(email: email);
      context.go(Routes.adminDashboard);
      return;
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final role = (res.user?.userMetadata?['role'] as String?) ?? 'tenant';
      if (role == 'admin') {
        context.go(Routes.adminDashboard);
      } else {
        context.go(Routes.tenantHome);
      }
    } on AuthException catch (e) {
      // Generic message to avoid leaking whether email exists
      setState(() {
        _errorMessage = _friendlyAuthError(e.message);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _quickDemoLogin() {
    _emailController.text = 'admin@rentify.app';
    _passwordController.text = 'RentifyAdmin@2026';
    ref.read(demoAuthProvider.notifier).loginAsAdmin(email: 'admin@rentify.app');
    context.go(Routes.adminDashboard);
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid') || lower.contains('credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Sign-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo & tagline ──────────────────────────
                  _buildLogo(),
                  SizedBox(height: isWide ? 48 : 40),

                  // ── Card ────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome back', style: AppTextStyles.h1),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to your Rentify account',
                            style: AppTextStyles.bodyRegular,
                          ),
                          const SizedBox(height: 28),

                          // Error banner
                          if (_errorMessage != null) ...[
                            _ErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          // Email
                          AppTextField(
                            label: 'Email address',
                            hint: 'you@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 16),

                          // Password
                          AppTextField(
                            label: 'Password',
                            hint: '••••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            prefixIcon: Icons.lock_outline_rounded,
                            onSubmitted: (_) => _signIn(),
                            validator: Validators.password,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: AppColors.inkMuted,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(Routes.forgotPassword),
                              child: Text(
                                'Forgot password?',
                                style: AppTextStyles.bodyRegular.copyWith(
                                  color: AppColors.action,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sign in button
                          AppButton(
                            label: 'Sign in securely',
                            onPressed: _isLoading ? null : _signIn,
                            isLoading: _isLoading,
                            icon: Icons.login_rounded,
                          ),

                          const SizedBox(height: 12),

                          // Quick Demo Admin button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(color: AppColors.action.withAlpha(120)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, color: AppColors.action, size: 20),
                            label: Text(
                              'Demo Admin (1-Click Login)',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.action,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _isLoading ? null : _quickDemoLogin,
                          ),

                          const SizedBox(height: 20),

                          // Biometric hint (shown only if possible)
                          const _BiometricHint(),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  const SizedBox(height: 32),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo mark
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'R',
              style: AppTextStyles.display.copyWith(
                color: Colors.white,
                fontSize: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Rentify', style: AppTextStyles.display),
        const SizedBox(height: 4),
        Text(
          'Rent management, simplified',
          style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Forgot password? Contact your administrator.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.inkDisabled,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyRegular.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Biometric hint ────────────────────────────────────────────────

class _BiometricHint extends StatelessWidget {
  const _BiometricHint();

  @override
  Widget build(BuildContext context) {
    // For now show a passive hint; actual biometric auth is in settings/session restore
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fingerprint_rounded,
            size: 18, color: AppColors.inkMuted),
        const SizedBox(width: 6),
        Text(
          'Biometric unlock available after first sign-in',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
