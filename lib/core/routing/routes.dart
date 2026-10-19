/// All route paths in one place.
/// Use named navigation: context.goNamed('dashboard') wherever possible.
class Routes {
  Routes._();

  // ── Auth ──────────────────────────────────────────────────────
  static const login = '/login';
  static const forgotPassword = '/forgot-password';

  // ── Admin ─────────────────────────────────────────────────────
  static const adminDashboard = '/admin/dashboard';
  static const tenantDirectory = '/admin/tenants';
  static const createTenant = '/admin/tenants/create';
  static const tenantProfile = '/admin/tenants';    // + /:tenancyId
  static const notifications = '/admin/notifications';
  static const reports = '/admin/reports';
  static const billing = '/admin/billing';
  static const settings = '/admin/settings';

  // ── Tenant ────────────────────────────────────────────────────
  static const tenantHome = '/tenant/home';
  static const tenantLedger = '/tenant/ledger';
  static const tenantNotifications = '/tenant/notifications';
  static const tenantDocuments = '/tenant/documents';
  static const tenantDetails = '/tenant/details';
  static const tenantSettings = '/tenant/settings';
}
