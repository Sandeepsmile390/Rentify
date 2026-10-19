import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/services/biometric_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: RentifyApp(),
    ),
  );
}

class RentifyApp extends ConsumerStatefulWidget {
  const RentifyApp({super.key});

  @override
  ConsumerState<RentifyApp> createState() => _RentifyAppState();
}

class _RentifyAppState extends ConsumerState<RentifyApp> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.initializeAndPrompt();
      _checkBiometricLock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricLock();
    }
  }

  Future<void> _checkBiometricLock() async {
    if (kIsWeb) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Unauthenticated users will be handled by login screen

    final isEnabled = await BiometricService.isBiometricEnabled();
    if (!isEnabled) return;

    if (_isAuthenticating) return;

    setState(() {
      _isLocked = true;
      _isAuthenticating = true;
    });

    final success = await BiometricService.authenticate(
      reason: 'Scan fingerprint or face to unlock Rentify',
    );

    if (mounted) {
      setState(() {
        _isLocked = !success;
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _triggerBiometricUnlock() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final success = await BiometricService.authenticate(
      reason: 'Scan fingerprint or face to unlock Rentify',
    );

    if (mounted) {
      setState(() {
        _isLocked = !success;
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _signOutFromLock() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    ref.read(demoAuthProvider.notifier).logout();
    if (mounted) {
      setState(() {
        _isLocked = false;
        _isAuthenticating = false;
      });
      ref.read(appRouterProvider).go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Rentify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (_isLocked)
              _BiometricLockOverlay(
                onUnlock: _triggerBiometricUnlock,
                onSignOut: _signOutFromLock,
                isAuthenticating: _isAuthenticating,
              ),
          ],
        );
      },
    );
  }
}

class _BiometricLockOverlay extends StatelessWidget {
  const _BiometricLockOverlay({
    required this.onUnlock,
    required this.onSignOut,
    required this.isAuthenticating,
  });

  final VoidCallback onUnlock;
  final VoidCallback onSignOut;
  final bool isAuthenticating;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'R',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Rentify is Locked', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Biometric authentication is required to access your account.',
                  style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(220, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isAuthenticating ? null : onUnlock,
                  icon: const Icon(Icons.fingerprint_rounded, size: 24),
                  label: Text(
                    isAuthenticating ? 'Verifying...' : 'Unlock with Biometrics',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onSignOut,
                  child: Text(
                    'Sign Out of Account',
                    style: AppTextStyles.captionBold.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
