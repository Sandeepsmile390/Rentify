import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
  _DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    // TODO: replace with real Supabase query via repository
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _data = _DashboardData.placeholder();
    });
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
              'October 2026',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
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
            onPressed: () => context.push(Routes.createTenant),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const _DashboardSkeleton()
          : _DashboardBody(data: _data!),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isTablet = width >= 600;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary stats row ──────────────────────────────
            _SummaryStatsRow(data: data, isWide: isTablet),
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
                  Expanded(flex: 2, child: _QuickAccess()),
                ],
              )
            else ...[
              _RecentActivity(events: data.recentEvents),
              const SizedBox(height: 16),
              _QuickAccess(),
            ],

            const SizedBox(height: 24),

            // ── Tenant list ────────────────────────────────────
            _TenantSection(tenants: data.tenants, isWide: isWide),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Summary stats cards ───────────────────────────────────────────

class _SummaryStatsRow extends StatelessWidget {
  const _SummaryStatsRow({required this.data, required this.isWide});
  final _DashboardData data;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: 'Total rent due',
        value: CurrencyFormatter.fromPaise(data.totalRentDuePaise),
        color: AppColors.amountDue,
        icon: Icons.home_work_outlined,
        bgColor: AppColors.errorBg,
      ),
      _StatCard(
        label: 'Electricity due',
        value: CurrencyFormatter.fromPaise(data.totalElecDuePaise),
        color: AppColors.warning,
        icon: Icons.bolt_rounded,
        bgColor: AppColors.warningBg,
      ),
      _StatCard(
        label: 'Collected this month',
        value: CurrencyFormatter.fromPaise(data.collectedThisMonthPaise),
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
        bgColor: AppColors.successBg,
      ),
      _StatCard(
        label: 'Active tenants',
        value: '${data.activeTenants} of ${data.totalTenants}',
        color: AppColors.action,
        icon: Icons.people_outline_rounded,
        bgColor: AppColors.actionBg,
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
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            ),
          if (data.pendingBills > 0)
            _AlertRow(
              icon: Icons.receipt_outlined,
              message: '${data.pendingBills} bills need attention',
              color: AppColors.warning,
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
  });
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
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
  const _QuickAccess();

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
            onTap: () => context.push(Routes.createTenant),
          ),
          _QuickItem(
            icon: Icons.receipt_long_outlined,
            label: 'Record payment',
            onTap: () => context.go(Routes.tenantDirectory),
          ),
          _QuickItem(
            icon: Icons.electric_meter_outlined,
            label: 'Enter meter reading',
            onTap: () => context.go(Routes.tenantDirectory),
          ),
          _QuickItem(
            icon: Icons.bar_chart_rounded,
            label: 'View reports',
            onTap: () => context.go(Routes.reports),
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
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: AppColors.inkMuted),
      onTap: onTap,
      minTileHeight: 52,
    );
  }
}

// ── Tenant list section ───────────────────────────────────────────

class _TenantSection extends StatefulWidget {
  const _TenantSection({required this.tenants, required this.isWide});
  final List<_TenantRow> tenants;
  final bool isWide;

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
          ...filtered.map((t) => _TenantListTile(tenant: t, isWide: widget.isWide)),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No tenants found', style: AppTextStyles.caption),
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
  const _TenantListTile({required this.tenant, required this.isWide});
  final _TenantRow tenant;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final hasDues = tenant.totalDuePaise > 0;
    final dueColor = hasDues ? AppColors.amountDue : AppColors.amountPositive;

    return InkWell(
      onTap: () =>
          context.push('${Routes.tenantProfile}/${tenant.tenancyId}'),
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
                  const Icon(Icons.chevron_right_rounded,
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

  factory _DashboardData.placeholder() => _DashboardData(
        totalRentDuePaise: 2231900,
        totalElecDuePaise: 250900,
        collectedThisMonthPaise: 466400,
        activeTenants: 8,
        totalTenants: 10,
        awaitingMeterReadings: 2,
        pendingBills: 1,
        recentEvents: [
          _ActivityEvent(
            icon: Icons.payments_rounded,
            iconColor: AppColors.success,
            iconBg: AppColors.successBg,
            title: 'Payment recorded — Manoj Kumar',
            subtitle: '₹5,500 cash · Room 03',
            time: '2h ago',
          ),
          _ActivityEvent(
            icon: Icons.electric_meter_outlined,
            iconColor: AppColors.warning,
            iconBg: AppColors.warningBg,
            title: 'Meter reading entered — Shop A',
            subtitle: '147.80 units · ₹1,330',
            time: '5h ago',
          ),
          _ActivityEvent(
            icon: Icons.person_add_outlined,
            iconColor: AppColors.action,
            iconBg: AppColors.actionBg,
            title: 'New tenant added — Priya Sharma',
            subtitle: 'Room 07 · Shop type',
            time: '1d ago',
          ),
          _ActivityEvent(
            icon: Icons.notifications_rounded,
            iconColor: AppColors.navy,
            iconBg: AppColors.navyLight.withOpacity(0.2),
            title: 'Monthly billing completed',
            subtitle: 'October 2026 · 8 charges generated',
            time: '2d ago',
          ),
        ],
        tenants: [
          _TenantRow(
            tenancyId: 'mock-1',
            name: 'Manoj Kumar',
            unit: 'Room 03',
            type: 'Room',
            rentDuePaise: 0,
            elecDuePaise: 0,
          ),
          _TenantRow(
            tenancyId: 'mock-2',
            name: 'Priya Sharma',
            unit: 'Room 07',
            type: 'Room',
            rentDuePaise: 550000,
            elecDuePaise: 135000,
          ),
          _TenantRow(
            tenancyId: 'mock-3',
            name: 'Ramesh Traders',
            unit: 'Shop A',
            type: 'Shop',
            rentDuePaise: 800000,
            elecDuePaise: 0,
          ),
          _TenantRow(
            tenancyId: 'mock-4',
            name: 'Sunita Devi',
            unit: 'Room 01',
            type: 'Room',
            rentDuePaise: 0,
            elecDuePaise: 0,
          ),
          _TenantRow(
            tenancyId: 'mock-5',
            name: 'Vikram Singh',
            unit: 'Room 12',
            type: 'Room',
            rentDuePaise: 450000,
            elecDuePaise: 90000,
          ),
        ],
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
  final int rentDuePaise;
  final int elecDuePaise;

  const _TenantRow({
    required this.tenancyId,
    required this.name,
    required this.unit,
    required this.type,
    required this.rentDuePaise,
    required this.elecDuePaise,
  });

  int get totalDuePaise => rentDuePaise + elecDuePaise;
}
