import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/biometric_service.dart';
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
  bool _canUseBiometrics = false;

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
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final enabled = await BiometricService.isBiometricEnabled();
      final hasSession = Supabase.instance.client.auth.currentSession != null;
      if (mounted) {
        setState(() => _canUseBiometrics = enabled && hasSession);
      }
    } catch (_) {}
  }

  Future<void> _unlockWithBiometrics() async {
    final success = await BiometricService.authenticate(
      reason: 'Scan fingerprint or face to unlock Rentify',
    );
    if (!success || !mounted) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      String role = '';
      try {
        final profile = await client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        role = (profile?['role'] as String?) ?? '';
      } catch (_) {}
      if (role.isEmpty) {
        role = (user.userMetadata?['role'] as String?) ?? 'tenant';
      }

      if (!mounted) return;
      if (role == 'admin') {
        context.go(Routes.adminDashboard);
      } else {
        context.go(Routes.tenantHome);
      }
    }
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

    final identifier = _emailController.text.trim();
    final idLower = identifier.toLowerCase();
    final rawDigits = identifier.replaceAll(RegExp(r'\D'), '');
    final cleanDigits = rawDigits.length >= 10 ? rawDigits.substring(rawDigits.length - 10) : rawDigits;
    var password = _passwordController.text;

    String loginEmail = identifier;

    // 1. Admin ID: sandeepsmile390, admin, or admin@rentify.app
    if (idLower == 'sandeepsmile390' || idLower == 'admin' || idLower == 'admin@rentify.app') {
      loginEmail = 'sandeepsmile390@rentify.app';
    } else if (cleanDigits.length == 10 && !identifier.contains('@')) {
      // 2. Tenant Mobile Number Login: Lookup account email securely via RPC
      final cleanPassDigits = password.replaceAll(RegExp(r'\D'), '');
      if (password.isEmpty ||
          cleanPassDigits == cleanDigits ||
          (cleanPassDigits.length >= 10 &&
              cleanPassDigits.substring(cleanPassDigits.length - 10) == cleanDigits)) {
        password = cleanDigits;
        _passwordController.text = cleanDigits;
      }

      try {
        final client = Supabase.instance.client;
        final res = await client.rpc(
          'get_tenant_login_email',
          params: {'p_mobile': cleanDigits},
        );

        if (res != null && res.toString().isNotEmpty) {
          loginEmail = res.toString().trim();
        } else {
          setState(() {
            _errorMessage = 'No active tenancy account found with mobile number $cleanDigits, or portal access has been disabled by landlord.';
          });
          return;
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Unable to resolve mobile account. Please verify your mobile number or check network: $e';
        });
        return;
      }
    }

    try {
      // Live Supabase Authentication
      AuthResponse res;
      try {
        res = await Supabase.instance.client.auth.signInWithPassword(
          email: loginEmail,
          password: password,
        );
      } catch (firstErr) {
        // Fallback for mobile logins: if user entered a custom password that failed, try default mobile number password
        if (cleanDigits.length == 10 && !identifier.contains('@') && password != cleanDigits) {
          res = await Supabase.instance.client.auth.signInWithPassword(
            email: loginEmail,
            password: cleanDigits,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      // Authoritative role check from server profile
      String role = '';
      if (res.user?.id != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', res.user!.id)
              .maybeSingle();
          role = (profile?['role'] as String?) ?? '';
        } catch (_) {}
      }
      if (role.isEmpty) {
        role = (res.user?.userMetadata?['role'] as String?) ?? 'tenant';
      }

      if (!mounted) return;
      if (role == 'admin') {
        context.go(Routes.adminDashboard);
      } else {
        context.go(Routes.tenantHome);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyAuthError(e.message);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign in failed. Please check your credentials and internet connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

                          // User ID / Mobile / Email
                          AppTextField(
                            label: 'User ID, Mobile Number or Email',
                            hint: 'sandeepsmile390 or 10-digit mobile',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber, AutofillHints.email],
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) {
                              final val = (v ?? '').trim();
                              if (val.isEmpty) return 'Please enter your User ID, mobile number or email';
                              final valLower = val.toLowerCase();
                              if (valLower == 'sandeepsmile390' || valLower == 'admin' || valLower == 'admin@rentify.app') return null;
                              final digits = val.replaceAll(RegExp(r'\D'), '');
                              if (digits.length >= 10 && !val.contains('@')) return null;
                              if (!val.contains('@')) return null;
                              return Validators.email(val);
                            },
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
                            validator: (v) {
                              final idVal = _emailController.text.trim().toLowerCase();
                              if (idVal == 'sandeepsmile390' || idVal == 'admin' || idVal == 'admin@rentify.app') {
                                if (v == null || v.isEmpty) return 'Password is required';
                                return null;
                              }
                              final digits = idVal.replaceAll(RegExp(r'\D'), '');
                              // If tenant enters mobile number, password defaults to mobile number if empty
                              if (digits.length >= 10 && !idVal.contains('@') && (v == null || v.isEmpty)) {
                                return null;
                              }
                              return Validators.password(v);
                            },
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

                          if (_canUseBiometrics) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.action),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.fingerprint_rounded, color: AppColors.action),
                              label: const Text('Unlock with Biometrics', style: TextStyle(color: AppColors.action, fontWeight: FontWeight.w600)),
                              onPressed: _isLoading ? null : _unlockWithBiometrics,
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            const _BiometricHint(),
                          ],
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
