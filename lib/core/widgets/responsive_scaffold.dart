import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../routing/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Desktop breakpoint — matches Figma: nav rail visible at ≥ 900 px.
const kDesktopBreakpoint = 900.0;

/// Tablet breakpoint — wider bottom nav / two-column layouts.
const kTabletBreakpoint = 600.0;

/// The outer shell that wraps all authenticated screens.
/// On mobile: bottom navigation bar.
/// On desktop (≥ 900 px): permanent navy side navigation rail.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.role,
    required this.child,
  });

  final String role; // 'admin' | 'tenant'
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kDesktopBreakpoint) {
      return _DesktopShell(role: role, child: child);
    }
    return _MobileShell(role: role, child: child);
  }
}

// ── Desktop shell ─────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.role, required this.child});
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = role == 'admin' ? _adminNavItems : _tenantNavItems;
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          _SideNav(items: items, location: location),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.items, required this.location});
  final List<_NavItem> items;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.navy,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.action,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'R',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rentify',
                    style: AppTextStyles.display.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: items.map((item) {
                  final selected = location.startsWith(item.path);
                  return _SideNavItem(item: item, selected: selected);
                }).toList(),
              ),
            ),
            // Bottom divider + sign-out
            const Divider(color: Colors.white12, height: 1),
            _SideNavItem(
              item: _NavItem(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                path: Routes.login,
              ),
              selected: false,
              isLogout: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends ConsumerWidget {
  const _SideNavItem({
    super.key,
    required this.item,
    required this.selected,
    this.isLogout = false,
  });
  final _NavItem item;
  final bool selected;
  final bool isLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isLogout) {
              _handleLogout(context, ref);
            } else {
              context.go(item.path);
            }
          },
          hoverColor: AppColors.navyLight,
          splashColor: Colors.white10,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyLight : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected
                      ? AppColors.navyTextSelected
                      : (isLogout ? Colors.redAccent : AppColors.navyText),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected
                      ? AppColors.navyTextSelected
                      : (isLogout ? Colors.redAccent : AppColors.navyText),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx, rootNavigator: true).pop(true),
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      ref.read(demoAuthProvider.notifier).logout();
      if (context.mounted) {
        context.go(Routes.login);
      }
    }
  }
}

// ── Mobile shell ──────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.role, required this.child});
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = role == 'admin' ? _adminNavItems : _tenantNavItems;
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = items.indexWhere((item) => location.startsWith(item.path));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(items[i].path),
          items: items
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon ?? item.icon),
                  label: item.label,
                  tooltip: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ── Nav item definitions ─────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String path;
}

const _adminNavItems = [
  _NavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Dashboard',
    path: Routes.adminDashboard,
  ),
  _NavItem(
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    label: 'Tenants',
    path: Routes.tenantDirectory,
  ),
  _NavItem(
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications_rounded,
    label: 'Alerts',
    path: Routes.notifications,
  ),
  _NavItem(
    icon: Icons.bar_chart_rounded,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Reports',
    path: Routes.reports,
  ),
  _NavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
    path: Routes.settings,
  ),
];

const _tenantNavItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
    path: Routes.tenantHome,
  ),
  _NavItem(
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    label: 'Ledger',
    path: Routes.tenantLedger,
  ),
  _NavItem(
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications_rounded,
    label: 'Alerts',
    path: Routes.tenantNotifications,
  ),
  _NavItem(
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    label: 'Docs',
    path: Routes.tenantDocuments,
  ),
];
