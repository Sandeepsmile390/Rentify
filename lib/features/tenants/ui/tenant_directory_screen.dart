import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/app_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/avatar_helper.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/widgets/status_chip.dart';
import '../services/tenancy_service.dart';

/// Figma frame 07 — Admin tenant directory (desktop + mobile adaptive)
class TenantDirectoryScreen extends ConsumerStatefulWidget {
  const TenantDirectoryScreen({super.key});

  @override
  ConsumerState<TenantDirectoryScreen> createState() =>
      _TenantDirectoryScreenState();
}

class _TenantDirectoryScreenState
    extends ConsumerState<TenantDirectoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all' | 'room' | 'shop'
  String _filterStatus = 'all'; // 'all' | 'dues' | 'clear'
  bool _isLoading = true;
  List<_TenantItem> _tenants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = AppCacheService.get<List<_TenantItem>>('tenant_directory');
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _tenants = cached;
        });
      }
    }

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('tenancies')
          .select('id, unit_id, tenant_type, tenant_name, mobile, is_active')
          .order('created_at', ascending: false);

      final List<dynamic> rows = res as List<dynamic>;

      // Fetch unpaid/partial charges
      final chargesRes = await client
          .from('charges')
          .select('id, tenancy_id, charge_type, amount_paise, status')
          .neq('status', 'paid')
          .neq('status', 'waived');

      // Fetch payment allocations
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

      final list = rows.map((t) {
        final tId = (t['id'] as String?) ?? '';
        return _TenantItem(
          tenancyId: tId,
          name: (t['tenant_name'] as String?) ?? 'Unnamed',
          unit: (t['unit_id'] as String?) ?? '—',
          type: (t['tenant_type'] as String?) == 'shop' ? 'Shop' : 'Room',
          mobile: (t['mobile'] as String?) ?? '',
          rentDuePaise: rentDueByTenancy[tId] ?? 0,
          elecDuePaise: elecDueByTenancy[tId] ?? 0,
          isActive: (t['is_active'] as bool?) ?? true,
        );
      }).toList();

      AppCacheService.set('tenant_directory', list);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tenants = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_tenants.isEmpty) _tenants = [];
      });
    }
  }

  List<_TenantItem> get _filtered {
    return _tenants.where((t) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.unit.toLowerCase().contains(q) ||
          t.mobile.contains(q);
      final matchesType = _filterType == 'all' ||
          t.type.toLowerCase() == _filterType;
      final matchesStatus = switch (_filterStatus) {
        'active' => t.isActive,
        'vacated' => !t.isActive,
        'dues' => t.totalDuePaise > 0,
        'clear' => t.totalDuePaise == 0,
        _ => true,
      };
      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Tenants', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () { setState(() => _isLoading = true); _load(); },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add tenant'),
              onPressed: () => context.push(Routes.createTenant),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────
          _FilterBar(
            searchController: _searchController,
            filterType: _filterType,
            filterStatus: _filterStatus,
            onSearch: (v) => setState(() => _searchQuery = v),
            onTypeChanged: (v) => setState(() => _filterType = v),
            onStatusChanged: (v) => setState(() => _filterStatus = v),
          ),

          // ── Summary row ─────────────────────────────────────
          if (!_isLoading) _SummaryRow(tenants: _tenants),

          const Divider(height: 1),

          // ── List ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: 400,
                              child: _EmptyState(
                                hasFilter: _searchQuery.isNotEmpty ||
                                    _filterType != 'all' ||
                                    _filterStatus != 'all',
                              ),
                            ),
                          )
                        : isWide
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: _TenantTable(
                                  tenants: _filtered,
                                  onRefresh: () {
                                    setState(() => _isLoading = true);
                                    _load();
                                  },
                                ),
                              )
                            : _TenantList(
                                tenants: _filtered,
                                onRefresh: () {
                                  setState(() => _isLoading = true);
                                  _load();
                                },
                              ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.filterType,
    required this.filterStatus,
    required this.onSearch,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });
  final TextEditingController searchController;
  final String filterType;
  final String filterStatus;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchController,
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Search by name, unit or mobile…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filterType == 'all' && filterStatus == 'all',
                  onTap: () {
                    onTypeChanged('all');
                    onStatusChanged('all');
                  },
                ),
                _FilterChip(
                  label: 'Active',
                  selected: filterStatus == 'active',
                  onTap: () => onStatusChanged(filterStatus == 'active' ? 'all' : 'active'),
                  selectedColor: AppColors.successBg,
                  selectedTextColor: AppColors.success,
                ),
                _FilterChip(
                  label: 'Vacated / Left',
                  selected: filterStatus == 'vacated',
                  onTap: () => onStatusChanged(filterStatus == 'vacated' ? 'all' : 'vacated'),
                  selectedColor: AppColors.surfaceVariant,
                  selectedTextColor: AppColors.inkMuted,
                ),
                _FilterChip(
                  label: 'Dues',
                  selected: filterStatus == 'dues',
                  onTap: () => onStatusChanged(filterStatus == 'dues' ? 'all' : 'dues'),
                  selectedColor: AppColors.errorBg,
                  selectedTextColor: AppColors.error,
                ),
                _FilterChip(
                  label: 'Rooms',
                  selected: filterType == 'room',
                  onTap: () => onTypeChanged(filterType == 'room' ? 'all' : 'room'),
                ),
                _FilterChip(
                  label: 'Shops',
                  selected: filterType == 'shop',
                  onTap: () => onTypeChanged(filterType == 'shop' ? 'all' : 'shop'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.selectedTextColor,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? selectedTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (selectedColor ?? AppColors.actionBg)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (selectedTextColor ?? AppColors.action)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: selected
                  ? (selectedTextColor ?? AppColors.action)
                  : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.tenants});
  final List<_TenantItem> tenants;

  @override
  Widget build(BuildContext context) {
    final total = tenants.length;
    final withDues = tenants.where((t) => t.totalDuePaise > 0).length;
    final totalDue = tenants.fold<int>(0, (s, t) => s + t.totalDuePaise);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$total tenants', style: AppTextStyles.captionBold),
          const SizedBox(width: 16),
          if (withDues > 0) ...[
            Container(width: 1, height: 12, color: AppColors.border),
            const SizedBox(width: 16),
            Text('$withDues with dues', style: AppTextStyles.captionBold.copyWith(color: AppColors.error)),
            const SizedBox(width: 8),
            Text('·', style: AppTextStyles.caption),
            const SizedBox(width: 8),
            Text(
              'Total: ${CurrencyFormatter.fromPaise(totalDue)}',
              style: AppTextStyles.captionBold.copyWith(color: AppColors.error),
            ),
          ] else ...[
            Text('All clear ✓', style: AppTextStyles.captionBold.copyWith(color: AppColors.success)),
          ],
        ],
      ),
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────

class _TenantTable extends StatelessWidget {
  const _TenantTable({required this.tenants, required this.onRefresh});
  final List<_TenantItem> tenants;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _H('Tenant')),
                Expanded(flex: 2, child: _H('Unit')),
                Expanded(flex: 2, child: _H('Mobile')),
                Expanded(flex: 2, child: _H('Rent due')),
                Expanded(flex: 2, child: _H('Elec due')),
                Expanded(flex: 2, child: _H('Total due')),
                Expanded(flex: 1, child: _H('Status')),
                SizedBox(width: 40),
              ],
            ),
          ),
          ...tenants.map((t) => _TableRow(tenant: t, onRefresh: onRefresh)),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.captionBold);
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.tenant, required this.onRefresh});
  final _TenantItem tenant;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasDues = tenant.totalDuePaise > 0;
    return InkWell(
      onTap: () => context.push('${Routes.tenantProfile}/${tenant.tenancyId}'),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  AvatarHelper.buildAvatar(name: tenant.name, radius: 16, fontSize: 13),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tenant.name,
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!tenant.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: const Text(
                          'Left / Vacated',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                    Text(tenant.type, style: AppTextStyles.caption),
                  ]),
                ),
              ],
            ),
          ),
            Expanded(flex: 2, child: Text(tenant.unit, style: AppTextStyles.bodyRegular)),
            Expanded(flex: 2, child: Text(tenant.mobile, style: AppTextStyles.bodyRegular)),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(tenant.rentDuePaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: tenant.rentDuePaise > 0 ? AppColors.amountDue : AppColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(tenant.elecDuePaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: tenant.elecDuePaise > 0 ? AppColors.warning : AppColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.fromPaise(tenant.totalDuePaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: hasDues ? AppColors.amountDue : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: !tenant.isActive
                  ? StatusChip(
                      label: hasDues ? 'Left (Dues)' : 'Vacated',
                      type: hasDues ? StatusChipType.error : StatusChipType.neutral,
                    )
                  : StatusChip(
                      label: hasDues ? 'Dues' : 'Clear',
                      type: hasDues ? StatusChipType.error : StatusChipType.success,
                    ),
            ),
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.inkMuted),
                tooltip: 'Tenant actions',
                onSelected: (val) {
                  if (val == 'view') {
                    context.push('${Routes.tenantProfile}/${tenant.tenancyId}');
                  } else if (val == 'pay') {
                    context.pushNamed('record-payment', pathParameters: {'tenancyId': tenant.tenancyId});
                  } else if (val == 'delete') {
                    _confirmDeleteTenantDirectory(context, tenant.tenancyId, tenant.name, onRefresh);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        SizedBox(width: 8),
                        Text('View profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pay',
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 18, color: AppColors.action),
                        SizedBox(width: 8),
                        Text('Record payment'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete tenant', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile list ───────────────────────────────────────────────────

class _TenantList extends StatelessWidget {
  const _TenantList({required this.tenants, required this.onRefresh});
  final List<_TenantItem> tenants;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: tenants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) => _MobileTenantTile(tenant: tenants[i], onRefresh: onRefresh),
    );
  }
}

class _MobileTenantTile extends StatelessWidget {
  const _MobileTenantTile({required this.tenant, required this.onRefresh});
  final _TenantItem tenant;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasDues = tenant.totalDuePaise > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: AvatarHelper.buildAvatar(
        name: tenant.name,
        radius: 20,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              tenant.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: tenant.isActive ? AppColors.ink : AppColors.inkMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!tenant.isActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: const Text(
                'Vacated',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${tenant.unit} · ${tenant.mobile}${tenant.isActive ? '' : ' · (Inactive)'}',
        style: AppTextStyles.caption,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.fromPaise(tenant.totalDuePaise),
                style: AppTextStyles.currencySmall.copyWith(
                  color: hasDues ? AppColors.amountDue : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (!tenant.isActive)
                StatusChip(
                  label: hasDues ? 'Left (Dues)' : 'Vacated',
                  type: hasDues ? StatusChipType.error : StatusChipType.neutral,
                )
              else
                StatusChip(
                  label: hasDues ? 'Dues' : 'Clear',
                  type: hasDues ? StatusChipType.error : StatusChipType.success,
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.inkMuted),
            tooltip: 'Actions',
            onSelected: (val) {
              if (val == 'view') {
                context.push('${Routes.tenantProfile}/${tenant.tenancyId}');
              } else if (val == 'pay') {
                context.pushNamed('record-payment', pathParameters: {'tenancyId': tenant.tenancyId});
              } else if (val == 'delete') {
                _confirmDeleteTenantDirectory(context, tenant.tenancyId, tenant.name, onRefresh);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 8),
                    Text('View profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pay',
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 18, color: AppColors.action),
                    SizedBox(width: 8),
                    Text('Record payment'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete tenant', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => context.push('${Routes.tenantProfile}/${tenant.tenancyId}'),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.search_off_rounded : Icons.people_outline_rounded,
            size: 56,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No tenants match your filter' : 'No tenants yet',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try clearing the search or filter'
                : 'Add your first tenant to get started',
            style: AppTextStyles.bodyRegular,
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add first tenant'),
              onPressed: () => context.push(Routes.createTenant),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Placeholder data ──────────────────────────────────────────────

class _TenantItem {
  final String tenancyId;
  final String name;
  final String unit;
  final String type;
  final String mobile;
  final int rentDuePaise;
  final int elecDuePaise;
  final bool isActive;

  const _TenantItem({
    required this.tenancyId,
    required this.name,
    required this.unit,
    required this.type,
    required this.mobile,
    required this.rentDuePaise,
    required this.elecDuePaise,
    this.isActive = true,
  });

  int get totalDuePaise => rentDuePaise + elecDuePaise;
}

Future<void> _confirmDeleteTenantDirectory(
  BuildContext context,
  String tenancyId,
  String tenantName,
  VoidCallback onDeleted,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Delete from Database?'),
        ],
      ),
      content: Text(
        'Are you sure you want to permanently delete $tenantName from the database?\n\n'
        'This will permanently delete the tenancy and all related records (charges, payments, meter readings, and advance ledgers) from the database.\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete Permanently'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('Deleting $tenantName from database…'),
        ],
      ),
      duration: const Duration(seconds: 15),
    ),
  );

  try {
    await TenancyService.deleteTenancyPermanently(tenancyId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tenant $tenantName deleted from database successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    onDeleted();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to delete tenant: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
