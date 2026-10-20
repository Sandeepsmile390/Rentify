import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/app_cache_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';

/// Figma frame 01 — Admin dashboard (desktop) & mobile-adapted version.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  _DashboardData? _data;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get _currentPeriodText {
    final now = DateTime.now();
    return '${_months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkForUpdates(context);
    });
  }

  Future<void> _loadDashboard() async {
    final cached = AppCacheService.get<_DashboardData>('admin_dashboard');
    if (cached != null && _data == null) {
      setState(() {
        _data = cached;
        _isLoading = false;
      });
    }
    try {
      final client = Supabase.instance.client;

      // 1. Fetch tenancies
      final res = await client
          .from('tenancies')
          .select('id, unit_id, tenant_type, tenant_name, mobile, is_active')
          .order('created_at', ascending: false);

      final List<dynamic> rows = res as List<dynamic>;

      // 2. Fetch unpaid/partial charges
      final chargesRes = await client
          .from('charges')
          .select('id, tenancy_id, charge_type, amount_paise, status')
          .neq('status', 'paid')
          .neq('status', 'waived');

      // 3. Fetch payment allocations to compute remaining dues
      final Map<String, int> allocatedByCharge = {};
      try {
        final allocRes = await client
            .from('payment_allocations')
            .select('charge_id, amount_paise, is_reversed')
            .eq('is_reversed', false);
        for (final a in (allocRes as List<dynamic>)) {
          final cId = (a['charge_id'] as String?) ?? '';
          final amt = (a['amount_paise'] as num?)?.toInt() ?? 0;
          allocatedByCharge[cId] = (allocatedByCharge[cId] ?? 0) + amt;
        }
      } catch (_) {}

      final Map<String, int> rentDueByTenancy = {};
      final Map<String, int> elecDueByTenancy = {};

      for (final c in (chargesRes as List<dynamic>)) {
        final tId = (c['tenancy_id'] as String?) ?? '';
        final cId = (c['id'] as String?) ?? '';
        final cType = (c['charge_type'] as String?) ?? 'rent';
        final originalAmt = (c['amount_paise'] as num?)?.toInt() ?? 0;
        final allocated = allocatedByCharge[cId] ?? 0;
        final remaining = (originalAmt - allocated).clamp(0, originalAmt);

        if (cType == 'rent') {
          rentDueByTenancy[tId] = (rentDueByTenancy[tId] ?? 0) + remaining;
        } else if (cType == 'electricity') {
          elecDueByTenancy[tId] = (elecDueByTenancy[tId] ?? 0) + remaining;
        }
      }

      int totalRentDue = 0;
      int totalElecDue = 0;
      int pendingBills = 0;
      int activeCount = 0;

      final tenants = rows.map((t) {
        final tId = (t['id'] as String?) ?? '';
        final bool isActive = (t['is_active'] as bool?) ?? true;
        if (isActive) activeCount++;
        final rDue = rentDueByTenancy[tId] ?? 0;
        final eDue = elecDueByTenancy[tId] ?? 0;
        final totalDue = rDue + eDue;

        totalRentDue += rDue;
        totalElecDue += eDue;
        if (totalDue > 0) pendingBills++;

        return _TenantRow(
          tenancyId: tId,
          name: (t['tenant_name'] as String?) ?? 'Unnamed',
          unit: (t['unit_id'] as String?) ?? '—',
          type: (t['tenant_type'] as String?) == 'shop' ? 'Shop' : 'Room',
          isActive: isActive,
          rentDuePaise: rDue,
          elecDuePaise: eDue,
        );
      }).toList();

      // 4. Collections this month
      int collectedThisMonth = 0;
      final now = DateTime.now();
      final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

      try {
        final paymentsRes = await client
            .from('payments')
            .select('amount_paise, payment_date')
            .eq('is_reversed', false)
            .gte('payment_date', monthStart);

        for (final p in (paymentsRes as List<dynamic>)) {
          collectedThisMonth += (p['amount_paise'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      // 5. Awaiting meter readings
      int awaitingMeterReadings = 0;
      try {
        final meterConfigs = await client
            .from('electricity_config')
            .select('tenancy_id, mode')
            .eq('mode', 'meter');

        final meterReadingsThisMonth = await client
            .from('meter_readings')
            .select('tenancy_id')
            .eq('billing_month', monthStart);

        final recordedTenancies = (meterReadingsThisMonth as List<dynamic>)
            .map((m) => (m['tenancy_id'] as String?) ?? '')
            .toSet();

        for (final mc in (meterConfigs as List<dynamic>)) {
          final tId = (mc['tenancy_id'] as String?) ?? '';
          if (tId.isNotEmpty && !recordedTenancies.contains(tId)) {
            awaitingMeterReadings++;
          }
        }
      } catch (_) {}

      // 6. Recent activity events
      final List<_ActivityEvent> recentEvents = [];
      try {
        final eventsRes = await client
            .from('payments')
            .select('amount_paise, method, payment_date, created_at, tenancy_id')
            .eq('is_reversed', false)
            .order('created_at', ascending: false)
            .limit(5);

        final Map<String, String> tenantNameMap = {
          for (final t in tenants) t.tenancyId: '${t.name} (${t.unit})'
        };

        for (final ev in (eventsRes as List<dynamic>)) {
          final amt = (ev['amount_paise'] as num?)?.toInt() ?? 0;
          final method = (ev['method'] as String?) ?? 'cash';
          final tId = (ev['tenancy_id'] as String?) ?? '';
          final tenantDesc = tenantNameMap[tId] ?? 'Tenant';

          recentEvents.add(_ActivityEvent(
            icon: Icons.payments_rounded,
            iconColor: AppColors.success,
            iconBg: AppColors.successBg,
            title: 'Payment: ${CurrencyFormatter.fromPaise(amt)}',
            subtitle: '$tenantDesc · ${method.toUpperCase()}',
            time: (ev['payment_date'] as String?) ?? 'Recent',
          ));
        }
      } catch (_) {}

      if (!mounted) return;
      final dashData = _DashboardData(
        totalRentDuePaise: totalRentDue,
        totalElecDuePaise: totalElecDue,
        collectedThisMonthPaise: collectedThisMonth,
        activeTenants: activeCount,
        totalTenants: tenants.length,
        awaitingMeterReadings: awaitingMeterReadings,
        pendingBills: pendingBills,
        recentEvents: recentEvents,
        tenants: tenants,
      );
      AppCacheService.set('admin_dashboard', dashData);

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _data = dashData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to refresh dashboard data. Please check connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: AppTextStyles.h2),
            Text(
              _currentPeriodText,
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDashboard();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add tenant',
            onPressed: () async {
              await context.push(Routes.createTenant);
              _loadDashboard();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _data == null
          ? const _DashboardSkeleton()
          : _errorMessage != null && _data == null
              ? _DashboardErrorView(
                  message: _errorMessage!,
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadDashboard();
                  },
                )
              : _DashboardBody(
                  data: _data ?? _DashboardData.empty(),
                  onRefresh: _loadDashboard,
                  errorMessage: _errorMessage,
                ),
    );
  }
}

// ── Dashboard error view ──────────────────────────────────────────

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Dashboard Unavailable', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardErrorBanner extends StatelessWidget {
  const _DashboardErrorBanner({
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text('Retry', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.onRefresh,
    this.errorMessage,
  });
  final _DashboardData data;
  final Future<void> Function() onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isTablet = width >= 600;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null) ...[
              _DashboardErrorBanner(
                message: errorMessage!,
                onRetry: onRefresh,
              ),
              const SizedBox(height: 16),
            ],
            // ── Summary stats row ──────────────────────────────
            _SummaryStatsRow(data: data, isWide: isTablet, onRefresh: onRefresh),
            const SizedBox(height: 20),

            // ── Alerts / action items ──────────────────────────
            if (data.awaitingMeterReadings > 0 || data.pendingBills > 0)
              _AlertsCard(data: data),
            if (data.awaitingMeterReadings > 0 || data.pendingBills > 0)
              const SizedBox(height: 20),

            // ── Recent activity + quick access ─────────────────
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _RecentActivity(events: data.recentEvents)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _QuickAccess(onRefresh: onRefresh)),
                ],
              )
            else ...[
              _RecentActivity(events: data.recentEvents),
              const SizedBox(height: 16),
              _QuickAccess(onRefresh: onRefresh),
            ],

            const SizedBox(height: 24),

            // ── Tenant list ────────────────────────────────────
            _TenantSection(
              tenants: data.tenants,
              isWide: isWide,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Summary stats cards ───────────────────────────────────────────

class _SummaryStatsRow extends StatelessWidget {
  const _SummaryStatsRow({
    required this.data,
    required this.isWide,
    required this.onRefresh,
  });
  final _DashboardData data;
  final bool isWide;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: 'Total rent due',
        value: CurrencyFormatter.fromPaise(data.totalRentDuePaise),
        color: AppColors.amountDue,
        icon: Icons.home_work_outlined,
        bgColor: AppColors.errorBg,
        onTap: () => context.go(Routes.tenantDirectory),
      ),
      _StatCard(
        label: 'Electricity due',
        value: CurrencyFormatter.fromPaise(data.totalElecDuePaise),
        color: AppColors.warning,
        icon: Icons.bolt_rounded,
        bgColor: AppColors.warningBg,
        onTap: () => _showElectricityDuesBreakdown(context, onRefresh),
      ),
      _StatCard(
        label: 'Collected this month',
        value: CurrencyFormatter.fromPaise(data.collectedThisMonthPaise),
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
        bgColor: AppColors.successBg,
        onTap: () => context.push(Routes.reports),
      ),
      _StatCard(
        label: 'Active tenants',
        value: '${data.activeTenants} of ${data.totalTenants}',
        color: AppColors.action,
        icon: Icons.people_outline_rounded,
        bgColor: AppColors.actionBg,
        onTap: () => context.go(Routes.tenantDirectory),
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: c,
                  ),
                ))
            .toList()
          ..last = Expanded(child: cards.last),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.bgColor,
    this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color bgColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.inkMuted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.currencyMedium.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

// ── Alerts card ───────────────────────────────────────────────────

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        children: [
          if (data.awaitingMeterReadings > 0)
            _AlertRow(
              icon: Icons.electric_meter_outlined,
              message:
                  '${data.awaitingMeterReadings} tenant${data.awaitingMeterReadings > 1 ? 's' : ''} awaiting meter reading',
              color: AppColors.warning,
              onTap: () => context.push(Routes.billing),
            ),
          if (data.pendingBills > 0)
            _AlertRow(
              icon: Icons.receipt_outlined,
              message: '${data.pendingBills} bills need attention',
              color: AppColors.warning,
              onTap: () => context.push(Routes.billing),
            ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.message,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

// ── Recent activity ───────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.events});
  final List<_ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text('Recent activity', style: AppTextStyles.h3),
          ),
          const Divider(height: 1),
          ...events.map((e) => _ActivityTile(event: e)),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No recent activity', style: AppTextStyles.caption),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.event});
  final _ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: event.iconBg,
        child: Icon(event.icon, size: 16, color: event.iconColor),
      ),
      title: Text(event.title, style: AppTextStyles.bodyMedium),
      subtitle: Text(event.subtitle, style: AppTextStyles.caption),
      trailing: Text(event.time, style: AppTextStyles.caption),
    );
  }
}

// ── Quick access ──────────────────────────────────────────────────

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({this.onRefresh});
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text('Quick access', style: AppTextStyles.h3),
          ),
          const Divider(height: 1),
          _QuickItem(
            icon: Icons.person_add_outlined,
            label: 'Add tenant',
            onTap: () async {
              await context.push(Routes.createTenant);
              onRefresh?.call();
            },
          ),
          _QuickItem(
            icon: Icons.receipt_long_outlined,
            label: 'Record payment',
            onTap: () async {
              await context.push(Routes.tenantDirectory);
              onRefresh?.call();
            },
          ),
          _QuickItem(
            icon: Icons.electric_meter_outlined,
            label: 'Enter meter reading',
            onTap: () async {
              await context.push(Routes.tenantDirectory);
              onRefresh?.call();
            },
          ),
          _QuickItem(
            icon: Icons.bar_chart_rounded,
            label: 'View reports',
            onTap: () => context.push(Routes.reports),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.action),
      title: Text(label, style: AppTextStyles.bodyMedium),
      trailing: Icon(Icons.chevron_right_rounded,
          size: 20, color: AppColors.inkMuted),
      onTap: onTap,
      minTileHeight: 52,
    );
  }
}

// ── Tenant list section ───────────────────────────────────────────

class _TenantSection extends StatefulWidget {
  const _TenantSection({
    required this.tenants,
    required this.isWide,
    required this.onRefresh,
  });
  final List<_TenantRow> tenants;
  final bool isWide;
  final Future<void> Function() onRefresh;

  @override
  State<_TenantSection> createState() => _TenantSectionState();
}

class _TenantSectionState extends State<_TenantSection> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tenants.where((t) {
      final q = _search.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.unit.toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text('Tenants', style: AppTextStyles.h3),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.people_outline_rounded, size: 16),
                  label: const Text('View all'),
                  onPressed: () => context.go(Routes.tenantDirectory),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or unit…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const Divider(height: 1),

          // Column headers (desktop only)
          if (widget.isWide) _TenantTableHeader(),

          // Rows
          ...filtered.map((t) => _TenantListTile(
                tenant: t,
                isWide: widget.isWide,
                onRefresh: widget.onRefresh,
              )),

          if (widget.tenants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_outlined, size: 44, color: AppColors.inkMuted),
                    const SizedBox(height: 12),
                    Text('No tenants added yet', style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Click "Add tenant" to register your first unit and tenant.',
                        style: AppTextStyles.caption, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Tenant'),
                      onPressed: () => context.push(Routes.createTenant),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No tenants found matching "$_search"', style: AppTextStyles.caption),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TenantTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 3, child: _HeaderCell('Tenant')),
          Expanded(flex: 2, child: _HeaderCell('Unit')),
          Expanded(flex: 2, child: _HeaderCell('Rent due')),
          Expanded(flex: 2, child: _HeaderCell('Electricity due')),
          Expanded(flex: 2, child: _HeaderCell('Total due')),
          Expanded(flex: 1, child: _HeaderCell('Status')),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.captionBold);
  }
}

class _TenantListTile extends StatelessWidget {
  const _TenantListTile({
    required this.tenant,
    required this.isWide,
    required this.onRefresh,
  });
  final _TenantRow tenant;
  final bool isWide;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasDues = tenant.totalDuePaise > 0;
    final dueColor = hasDues ? AppColors.amountDue : AppColors.amountPositive;

    return InkWell(
      onTap: () async {
        await context.push('${Routes.tenantProfile}/${tenant.tenancyId}');
        onRefresh();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
          color: hasDues
              ? const Color(0xFFFFFAFA)
              : null,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isWide ? 12 : 14,
        ),
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenant.name, style: AppTextStyles.bodyMedium),
                        Text(tenant.type, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(tenant.unit, style: AppTextStyles.bodyRegular),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.fromPaise(tenant.rentDuePaise),
                      style: AppTextStyles.currencySmall.copyWith(
                        color: tenant.rentDuePaise > 0
                            ? AppColors.amountDue
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.fromPaise(tenant.elecDuePaise),
                      style: AppTextStyles.currencySmall.copyWith(
                        color: tenant.elecDuePaise > 0
                            ? AppColors.warning
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.fromPaise(tenant.totalDuePaise),
                      style: AppTextStyles.currencySmall.copyWith(
                        color: dueColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: StatusChip(
                      label: hasDues ? 'Dues' : 'Clear',
                      type: hasDues ? StatusChipType.error : StatusChipType.success,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.inkMuted),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenant.name, style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${tenant.unit} · ${tenant.type}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.fromPaise(tenant.totalDuePaise),
                        style: AppTextStyles.currencySmall.copyWith(
                          color: dueColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusChip(
                        label: hasDues ? 'Dues' : 'Clear',
                        type: hasDues
                            ? StatusChipType.error
                            : StatusChipType.success,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.inkMuted),
                ],
              ),
      ),
    );
  }
}

// ── Skeleton loader ───────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

// ── Data models (will move to repository layer) ───────────────────

class _DashboardData {
  final int totalRentDuePaise;
  final int totalElecDuePaise;
  final int collectedThisMonthPaise;
  final int activeTenants;
  final int totalTenants;
  final int awaitingMeterReadings;
  final int pendingBills;
  final List<_ActivityEvent> recentEvents;
  final List<_TenantRow> tenants;

  const _DashboardData({
    required this.totalRentDuePaise,
    required this.totalElecDuePaise,
    required this.collectedThisMonthPaise,
    required this.activeTenants,
    required this.totalTenants,
    required this.awaitingMeterReadings,
    required this.pendingBills,
    required this.recentEvents,
    required this.tenants,
  });

  factory _DashboardData.empty() => const _DashboardData(
        totalRentDuePaise: 0,
        totalElecDuePaise: 0,
        collectedThisMonthPaise: 0,
        activeTenants: 0,
        totalTenants: 0,
        awaitingMeterReadings: 0,
        pendingBills: 0,
        recentEvents: [],
        tenants: [],
      );
}

class _ActivityEvent {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityEvent({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _TenantRow {
  final String tenancyId;
  final String name;
  final String unit;
  final String type;
  final bool isActive;
  final int rentDuePaise;
  final int elecDuePaise;

  const _TenantRow({
    required this.tenancyId,
    required this.name,
    required this.unit,
    required this.type,
    this.isActive = true,
    required this.rentDuePaise,
    required this.elecDuePaise,
  });

  int get totalDuePaise => rentDuePaise + elecDuePaise;
}

// ── Electricity Dues Breakdown Sheet ─────────────────────────────

Future<void> _showElectricityDuesBreakdown(
  BuildContext context,
  Future<void> Function() onRefresh,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ElectricityDuesBreakdownSheet(onRefresh: onRefresh),
  );
}

class _ElectricityDuesBreakdownSheet extends StatefulWidget {
  const _ElectricityDuesBreakdownSheet({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  State<_ElectricityDuesBreakdownSheet> createState() =>
      _ElectricityDuesBreakdownSheetState();
}

class _ElectricityDuesBreakdownSheetState
    extends State<_ElectricityDuesBreakdownSheet> {
  bool _isLoading = true;
  String? _error;
  List<_TenantElecGroup> _allGroups = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDues();
  }

  Future<void> _loadDues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      final allocRows = await client
          .from('charge_allocation_totals')
          .select('charge_id, tenancy_id, charge_type, billing_month, amount_paise, allocated_paise, outstanding_paise')
          .eq('charge_type', 'electricity')
          .gt('outstanding_paise', 0)
          .order('billing_month', ascending: false);

      final tenancyIds = (allocRows as List)
          .map((r) => r['tenancy_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> tenancyMap = {};
      if (tenancyIds.isNotEmpty) {
        final tRows = await client
            .from('tenancies')
            .select('id, tenant_name, unit_id, mobile, is_active')
            .filter('id', 'in', tenancyIds);
        for (final t in (tRows as List)) {
          tenancyMap[t['id'].toString()] = t as Map<String, dynamic>;
        }
      }

      final Map<String, List<_MonthElecItem>> byTenancy = {};
      for (final r in (allocRows as List)) {
        final tId = r['tenancy_id']?.toString() ?? '';
        final cId = r['charge_id']?.toString() ?? '';
        final bMonth = r['billing_month']?.toString() ?? '';
        final amt = (r['amount_paise'] as num?)?.toInt() ?? 0;
        final alloc = (r['allocated_paise'] as num?)?.toInt() ?? 0;
        final out = (r['outstanding_paise'] as num?)?.toInt() ?? 0;

        byTenancy.putIfAbsent(tId, () => []).add(
          _MonthElecItem(
            chargeId: cId,
            billingMonth: bMonth,
            amountPaise: amt,
            allocatedPaise: alloc,
            outstandingPaise: out,
          ),
        );
      }

      final List<_TenantElecGroup> groups = [];
      byTenancy.forEach((tId, months) {
        final tInfo = tenancyMap[tId];
        final name = (tInfo?['tenant_name'] as String?) ?? 'Tenant';
        final unit = (tInfo?['unit_id'] as String?) ?? '—';
        final mobile = (tInfo?['mobile'] as String?) ?? '';
        final isActive = (tInfo?['is_active'] as bool?) ?? true;

        months.sort((a, b) => b.billingMonth.compareTo(a.billingMonth));
        final totalDue = months.fold<int>(0, (sum, m) => sum + m.outstandingPaise);

        groups.add(
          _TenantElecGroup(
            tenancyId: tId,
            tenantName: name,
            unitId: unit,
            mobile: mobile,
            isActive: isActive,
            totalDuePaise: totalDue,
            months: months,
          ),
        );
      });

      groups.sort((a, b) => b.totalDuePaise.compareTo(a.totalDuePaise));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _allGroups = groups;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load electricity dues: $e';
        });
      }
    }
  }

  void _shareWhatsAppNotice(_TenantElecGroup group) {
    final buffer = StringBuffer();
    buffer.writeln('Hello ${group.tenantName},');
    buffer.writeln('');
    buffer.writeln('This is a reminder for pending *ELECTRICITY DUES* for Unit *${group.unitId}*:');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    for (final m in group.months) {
      buffer.writeln('• *${m.formattedMonth}*: ${CurrencyFormatter.fromPaise(m.outstandingPaise)} due (Billed: ${CurrencyFormatter.fromPaise(m.amountPaise)})');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Total Electricity Due: ${CurrencyFormatter.fromPaise(group.totalDuePaise)}*');
    buffer.writeln('');
    buffer.writeln('Please clear the outstanding electricity bill at your earliest convenience.');
    buffer.writeln('Thank you!');

    final msg = buffer.toString();
    if (group.mobile.isNotEmpty) {
      final uri = WhatsAppService.buildWhatsAppUri(phone: group.mobile, message: msg);
      launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
        _copyToClipboard(msg);
        return false;
      });
    } else {
      _copyToClipboard(msg);
    }
  }

  void _copyToClipboard(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notice copied to clipboard! (No mobile number found)'),
        backgroundColor: AppColors.action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    final filteredGroups = _allGroups.where((g) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final inName = g.tenantName.toLowerCase().contains(q);
      final inUnit = g.unitId.toLowerCase().contains(q);
      final inMonth = g.months.any((m) => m.formattedMonth.toLowerCase().contains(q));
      return inName || inUnit || inMonth;
    }).toList();

    final grandTotalPaise = _allGroups.fold<int>(0, (sum, g) => sum + g.totalDuePaise);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Electricity Dues Breakdown',
                        style: AppTextStyles.h2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tenant-wise and month-wise outstanding charges',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Summary bar & Search box
          if (!_isLoading && _error == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL ELECTRICITY DUE',
                            style: AppTextStyles.captionBold.copyWith(fontSize: 10, letterSpacing: 0.5, color: AppColors.inkMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.fromPaise(grandTotalPaise),
                            style: AppTextStyles.h1.copyWith(
                              color: grandTotalPaise > 0 ? AppColors.warning : AppColors.success,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: grandTotalPaise > 0 ? AppColors.warningBg : AppColors.successBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_allGroups.length} Tenants with dues',
                        style: AppTextStyles.captionBold.copyWith(
                          color: grandTotalPaise > 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by tenant name, unit or month...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyRegular),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: _loadDues, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : filteredGroups.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No matching electricity dues'
                                        : 'All Electricity Dues Cleared!',
                                    style: AppTextStyles.h2,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Try searching with a different name, room or month.'
                                        : 'No tenants have outstanding electricity charges recorded in the system.',
                                    style: AppTextStyles.bodyRegular.copyWith(color: AppColors.inkMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filteredGroups.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final group = filteredGroups[index];
                              return _TenantElecCard(
                                group: group,
                                onWhatsApp: () => _shareWhatsAppNotice(group),
                                onRecordPayment: () async {
                                  Navigator.pop(ctx);
                                  await context.pushNamed(
                                    'record-payment',
                                    pathParameters: {'tenancyId': group.tenancyId},
                                  );
                                  await widget.onRefresh();
                                },
                                onViewProfile: () {
                                  Navigator.pop(ctx);
                                  context.pushNamed(
                                    'tenant-profile',
                                    pathParameters: {'tenancyId': group.tenancyId},
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _TenantElecCard extends StatelessWidget {
  const _TenantElecCard({
    required this.group,
    required this.onWhatsApp,
    required this.onRecordPayment,
    required this.onViewProfile,
  });

  final _TenantElecGroup group;
  final VoidCallback onWhatsApp;
  final VoidCallback onRecordPayment;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tenant header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                  child: Text(
                    group.tenantName.isNotEmpty ? group.tenantName[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.tenantName,
                              style: AppTextStyles.h3.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              group.unitId,
                              style: AppTextStyles.captionBold.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.mobile.isNotEmpty ? group.mobile : 'No mobile registered',
                        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${CurrencyFormatter.fromPaise(group.totalDuePaise)} due',
                    style: AppTextStyles.captionBold.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Month-wise breakdown table
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONTH-WISE BREAKDOWN',
                  style: AppTextStyles.captionBold.copyWith(fontSize: 10, letterSpacing: 0.5, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 6),
                ...group.months.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.inkMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              m.formattedMonth,
                              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                            ),
                          ),
                          Text(
                            'Billed ${CurrencyFormatter.fromPaise(m.amountPaise)}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${CurrencyFormatter.fromPaise(m.outstandingPaise)} due',
                              style: AppTextStyles.captionBold.copyWith(color: AppColors.amountDue),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onWhatsApp,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('WhatsApp Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: onViewProfile,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Profile', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onRecordPayment,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantElecGroup {
  final String tenancyId;
  final String tenantName;
  final String unitId;
  final String mobile;
  final bool isActive;
  final int totalDuePaise;
  final List<_MonthElecItem> months;

  const _TenantElecGroup({
    required this.tenancyId,
    required this.tenantName,
    required this.unitId,
    required this.mobile,
    required this.isActive,
    required this.totalDuePaise,
    required this.months,
  });
}

class _MonthElecItem {
  final String chargeId;
  final String billingMonth;
  final int amountPaise;
  final int allocatedPaise;
  final int outstandingPaise;

  const _MonthElecItem({
    required this.chargeId,
    required this.billingMonth,
    required this.amountPaise,
    required this.allocatedPaise,
    required this.outstandingPaise,
  });

  String get formattedMonth {
    try {
      final parts = billingMonth.split('-');
      if (parts.length >= 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final dt = DateTime(y, m, 1);
        return DateFormat('MMMM yyyy').format(dt);
      }
      return billingMonth;
    } catch (_) {
      return billingMonth;
    }
  }
}

