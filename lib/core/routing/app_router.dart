import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/dashboard/ui/admin_dashboard_screen.dart';
import '../../features/tenants/ui/tenant_directory_screen.dart';
import '../../features/tenants/ui/create_tenant_screen.dart';
import '../../features/tenant_profile/ui/tenant_profile_screen.dart';
import '../../features/ledger/ui/tenant_ledger_screen.dart';
import '../../features/payments/ui/record_payment_screen.dart';
import '../../features/electricity/ui/meter_reading_screen.dart';
import '../../features/advances/ui/advance_management_screen.dart';
import '../../features/notifications/ui/notification_center_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/audit/ui/audit_trail_screen.dart';
import '../../features/reports/ui/reports_screen.dart';
import '../../features/billing/ui/billing_screen.dart';
import '../../features/documents/ui/documents_screen.dart';
import '../widgets/responsive_scaffold.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isAuthenticatedProvider);
  final role = ref.watch(currentRoleProvider);

  return GoRouter(
    initialLocation: Routes.login,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.forgotPassword;

      if (!isLoggedIn && !isLoginRoute) return Routes.login;
      if (isLoggedIn && isLoginRoute) {
        return role == 'admin' ? Routes.adminDashboard : Routes.tenantHome;
      }
      return null;
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────
      GoRoute(
        path: Routes.login,
        name: 'login',
        pageBuilder: (context, state) => _fadeTransition(
          state,
          const LoginScreen(),
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: 'forgot-password',
        pageBuilder: (context, state) => _slideTransition(
          state,
          const ForgotPasswordScreen(),
        ),
      ),

      // ── Admin shell ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ResponsiveScaffold(
          role: 'admin',
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            name: 'admin-dashboard',
            pageBuilder: (context, state) =>
                _noTransition(state, const AdminDashboardScreen()),
          ),
          GoRoute(
            path: Routes.tenantDirectory,
            name: 'tenant-directory',
            pageBuilder: (context, state) =>
                _noTransition(state, const TenantDirectoryScreen()),
          ),
          GoRoute(
            path: Routes.createTenant,
            name: 'create-tenant',
            pageBuilder: (context, state) =>
                _slideTransition(state, const CreateTenantScreen()),
          ),
          GoRoute(
            path: '${Routes.tenantProfile}/:tenancyId',
            name: 'tenant-profile',
            pageBuilder: (context, state) => _slideTransition(
              state,
              TenantProfileScreen(
                tenancyId: state.pathParameters['tenancyId']!,
              ),
            ),
            routes: [
              GoRoute(
                path: 'payment',
                name: 'record-payment',
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  RecordPaymentScreen(
                    tenancyId: state.pathParameters['tenancyId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'meter',
                name: 'meter-reading',
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  MeterReadingScreen(
                    tenancyId: state.pathParameters['tenancyId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'advances',
                name: 'advances',
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  AdvanceManagementScreen(
                    tenancyId: state.pathParameters['tenancyId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'audit',
                name: 'audit-trail',
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  AuditTrailScreen(
                    tenancyId: state.pathParameters['tenancyId']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'documents',
                name: 'admin-documents',
                pageBuilder: (context, state) => _slideTransition(
                  state,
                  DocumentsScreen(
                    tenancyId: state.pathParameters['tenancyId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.notifications,
            name: 'notifications',
            pageBuilder: (context, state) =>
                _noTransition(state, const NotificationCenterScreen()),
          ),
          GoRoute(
            path: Routes.reports,
            name: 'reports',
            pageBuilder: (context, state) =>
                _noTransition(state, const ReportsScreen()),
          ),
          GoRoute(
            path: Routes.billing,
            name: 'billing',
            pageBuilder: (context, state) =>
                _noTransition(state, const BillingScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            name: 'settings',
            pageBuilder: (context, state) =>
                _noTransition(state, const SettingsScreen()),
          ),
        ],
      ),

      // ── Tenant shell ────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ResponsiveScaffold(
          role: 'tenant',
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.tenantHome,
            name: 'tenant-home',
            pageBuilder: (context, state) =>
                _noTransition(state, const TenantLedgerScreen(isTenantHome: true)),
          ),
          GoRoute(
            path: Routes.tenantLedger,
            name: 'tenant-ledger',
            pageBuilder: (context, state) =>
                _noTransition(state, const TenantLedgerScreen(isTenantHome: false)),
          ),
          GoRoute(
            path: Routes.tenantNotifications,
            name: 'tenant-notifications',
            pageBuilder: (context, state) =>
                _noTransition(state, const NotificationCenterScreen()),
          ),
          GoRoute(
            path: Routes.tenantDocuments,
            name: 'tenant-documents',
            pageBuilder: (context, state) =>
                _noTransition(state, const DocumentsScreen()),
          ),
          GoRoute(
            path: Routes.tenantSettings,
            name: 'tenant-settings',
            pageBuilder: (context, state) =>
                _noTransition(state, const SettingsScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
});

// ── Page transitions ──────────────────────────────────────────────

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, c) =>
          FadeTransition(opacity: animation, child: c),
    );

CustomTransitionPage<void> _slideTransition(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, c) {
        final tween = Tween(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: animation.drive(tween), child: c),
        );
      },
    );

CustomTransitionPage<void> _noTransition(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

// ── Error screen ─────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('Go to login'),
            ),
          ],
        ),
      ),
    );
  }
}
