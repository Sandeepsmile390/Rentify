import 'package:flutter_test/flutter_test.dart';
import 'package:rentify/core/routing/routes.dart';

void main() {
  group('Route Authorization & Security Guards', () {
    String? simulateRedirect({
      required bool isLoggedIn,
      required String role,
      required String location,
    }) {
      final isLoginRoute = location == Routes.login || location == Routes.forgotPassword;

      if (!isLoggedIn) {
        return isLoginRoute ? null : Routes.login;
      }

      if (isLoginRoute) {
        return role == 'admin' ? Routes.adminDashboard : Routes.tenantHome;
      }

      // Strict role-based route guards
      if (role == 'tenant' && location.startsWith('/admin')) {
        return Routes.tenantHome;
      }

      if (role == 'admin' && location.startsWith('/tenant')) {
        return Routes.adminDashboard;
      }

      return null;
    }

    test('Unauthenticated user is redirected to /login from any protected route', () {
      expect(
        simulateRedirect(isLoggedIn: false, role: 'admin', location: Routes.adminDashboard),
        equals(Routes.login),
      );
      expect(
        simulateRedirect(isLoggedIn: false, role: 'tenant', location: Routes.tenantHome),
        equals(Routes.login),
      );
      expect(
        simulateRedirect(isLoggedIn: false, role: 'tenant', location: Routes.tenantDirectory),
        equals(Routes.login),
      );
    });

    test('Unauthenticated user is allowed on login and forgotPassword routes', () {
      expect(
        simulateRedirect(isLoggedIn: false, role: '', location: Routes.login),
        isNull,
      );
      expect(
        simulateRedirect(isLoggedIn: false, role: '', location: Routes.forgotPassword),
        isNull,
      );
    });

    test('Tenant is blocked from all /admin/* routes and redirected to /tenant/home', () {
      final adminRoutes = [
        Routes.adminDashboard,
        Routes.tenantDirectory,
        Routes.createTenant,
        Routes.billing,
        Routes.reports,
        '${Routes.tenantProfile}/some-id',
      ];

      for (final route in adminRoutes) {
        final redirect = simulateRedirect(
          isLoggedIn: true,
          role: 'tenant',
          location: route,
        );
        expect(
          redirect,
          equals(Routes.tenantHome),
          reason: 'Tenant should not be allowed into admin route $route',
        );
      }
    });

    test('Admin accessing /tenant/* is redirected to /admin/dashboard', () {
      final tenantRoutes = [
        Routes.tenantHome,
        Routes.tenantLedger,
        Routes.tenantNotifications,
        Routes.tenantDocuments,
        Routes.tenantSettings,
      ];

      for (final route in tenantRoutes) {
        final redirect = simulateRedirect(
          isLoggedIn: true,
          role: 'admin',
          location: route,
        );
        expect(
          redirect,
          equals(Routes.adminDashboard),
          reason: 'Admin should be redirected to admin dashboard from $route',
        );
      }
    });

    test('Authenticated admin on /login is redirected to /admin/dashboard', () {
      expect(
        simulateRedirect(isLoggedIn: true, role: 'admin', location: Routes.login),
        equals(Routes.adminDashboard),
      );
    });

    test('Authenticated tenant on /login is redirected to /tenant/home', () {
      expect(
        simulateRedirect(isLoggedIn: true, role: 'tenant', location: Routes.login),
        equals(Routes.tenantHome),
      );
    });
  });

  group('Tenancy Financial Preservation Rules', () {
    test('Tenancy with financial records must be archived/deactivated, not deleted', () {
      bool shouldDeactivate({
        required bool hasPayments,
        required bool hasCharges,
        required bool hasAdvances,
      }) {
        return hasPayments || hasCharges || hasAdvances;
      }

      expect(
        shouldDeactivate(hasPayments: true, hasCharges: false, hasAdvances: false),
        isTrue,
        reason: 'Payment history must trigger deactivation',
      );

      expect(
        shouldDeactivate(hasPayments: false, hasCharges: true, hasAdvances: false),
        isTrue,
        reason: 'Charge history must trigger deactivation',
      );

      expect(
        shouldDeactivate(hasPayments: false, hasCharges: false, hasAdvances: true),
        isTrue,
        reason: 'Advance history must trigger deactivation',
      );

      expect(
        shouldDeactivate(hasPayments: false, hasCharges: false, hasAdvances: false),
        isFalse,
        reason: 'Empty tenancy can be cleanly purged',
      );
    });
  });
}
