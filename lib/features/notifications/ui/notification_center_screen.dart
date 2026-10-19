import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

/// Notification center — for both admin (all notifications) and tenant (own & live tenancy alerts)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  bool _isLoading = true;
  String _userRole = 'tenant';
  List<_NotifItem> _items = [];

  static const _dismissedPrefsKey = 'rentify_dismissed_notification_ids';
  static const _readPrefsKey = 'rentify_read_notification_ids';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();

      final dismissedIds = prefs.getStringList(_dismissedPrefsKey)?.toSet() ?? <String>{};
      final readIds = prefs.getStringList(_readPrefsKey)?.toSet() ?? <String>{};

      // Check current user role
      String userRole = 'admin';
      if (userId != null) {
        try {
          final profile = await client
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
          if (profile != null && profile['role'] != null) {
            userRole = profile['role'] as String;
          }
        } catch (_) {}
      }

      final res = await client
          .from('notifications')
          .select('*')
          .neq('for_role', 'archived')
          .order('created_at', ascending: false)
          .limit(50);

      final rows = res as List<dynamic>;
      final list = rows.where((r) {
        final id = (r['id'] as String?) ?? '';
        if (dismissedIds.contains(id)) return false;

        if (userRole == 'admin') return true;
        final forRole = (r['for_role'] as String?)?.toLowerCase();
        final rId = r['recipient_id'] as String?;
        return forRole == 'tenant' || forRole == 'all' || rId == userId || forRole == null;
      }).map((r) {
        final id = (r['id'] as String?) ?? '';
        final d = DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime.now();
        final diff = DateTime.now().difference(d);
        String timeAgo;
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes.clamp(1, 60)}m ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inDays}d ago';
        }

        final rawBody = (r['body'] as String?) ?? (r['message'] as String?) ?? '';
        final rawTitle = (r['title'] as String?) ?? 'Notice';
        final isDbRead = (r['is_read'] as bool?) ?? (r['read'] as bool?) ?? false;

        return _NotifItem(
          id: id,
          category: (r['category'] as String?) ?? 'system',
          title: rawTitle,
          body: rawBody,
          timeAgo: timeAgo,
          isRead: isDbRead || readIds.contains(id),
        );
      }).toList();

      // ── Generate live tenancy alerts for tenant ──────────────────────
      if (userRole == 'tenant' && userId != null) {
        try {
          final tenancy = await client
              .from('tenancies')
              .select('id, unit_id')
              .eq('profile_id', userId)
              .maybeSingle();

          if (tenancy != null) {
            final tId = tenancy['id'] as String;
            final uId = tenancy['unit_id'] as String? ?? 'Unit';

            // Query active outstanding dues for this tenancy
            final chargesRes = await client
                .from('charges')
                .select('amount_paise, charge_type')
                .eq('tenancy_id', tId);

            final paymentsRes = await client
                .from('payments')
                .select('amount_paise')
                .eq('tenancy_id', tId);

            int totalCharges = 0;
            for (final c in chargesRes as List) {
              totalCharges += ((c['amount_paise'] as num?)?.toInt() ?? 0);
            }

            int totalPayments = 0;
            for (final p in paymentsRes as List) {
              totalPayments += ((p['amount_paise'] as num?)?.toInt() ?? 0);
            }

            final outstanding = (totalCharges - totalPayments).clamp(0, 999999999);
            final liveDuesId = 'live-dues-$tId-${DateTime.now().month}';

            if (outstanding > 0 && !dismissedIds.contains(liveDuesId)) {
              list.insert(
                0,
                _NotifItem(
                  id: liveDuesId,
                  category: 'bill',
                  title: 'Pending Dues for $uId: ${CurrencyFormatter.fromPaise(outstanding)}',
                  body:
                      'You have an outstanding balance of ${CurrencyFormatter.fromPaise(outstanding)}. Please clear your dues or view your itemized ledger.',
                  timeAgo: 'Live',
                  isRead: readIds.contains(liveDuesId),
                ),
              );
            }
          }
        } catch (_) {}

        // App update available notification
        const updateNotifId = 'live-update-notice-v1.1.0+3';
        if (!dismissedIds.contains(updateNotifId)) {
          list.insert(
            0,
            _NotifItem(
              id: updateNotifId,
              category: 'system',
              title: '🚀 Rentify App Update Available',
              body:
                  'A new update is available with enhanced performance, quick biometric lock, and read-only details. Tap to download APK.',
              timeAgo: 'Update',
              isRead: readIds.contains(updateNotifId),
              actionUrl: UpdateService.defaultApkUrl,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _userRole = userRole;
        _items = list;
      });
    } catch (e) {
      debugPrint('Notice loading notifications: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = [];
      });
    }
  }

  Future<void> _sendTestAlert() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      await client.from('notifications').insert({
        'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
        if (userId != null) 'recipient_id': userId,
        'for_role': 'admin',
        'category': 'payment',
        'title': '🔔 Rentify Live System Alert',
        'body': 'Push notifications and system tray alerts are working live on your device!',
        'message': 'Push notifications and system tray alerts are working live on your device!',
        'is_read': false,
        'read': false,
      });

      // Request or verify permission
      await NotificationService.requestPermission();

      // Show actionable system tray notification on phone
      await NotificationService.showSystemNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '🔔 Rentify Live System Alert',
        body: 'Push notifications and system tray alerts are working live on your device!',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live notification sent and posted to device status bar!'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _isLoading = true);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showBroadcastSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedRole = 'tenant';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          top: 24, left: 24, right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Broadcast Notice', style: AppTextStyles.h2),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Notice Title',
                hintText: 'e.g. Water Tank Maintenance, Rent Reminder',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                hintText: 'Enter announcement details for tenants...',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Broadcast Notice'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final msg = bodyCtrl.text.trim();
                if (title.isEmpty || msg.isEmpty) return;

                Navigator.pop(sheetCtx);
                try {
                  final client = Supabase.instance.client;
                  await client.from('notifications').insert({
                    'id': 'notif-${DateTime.now().millisecondsSinceEpoch}',
                    'title': '📢 $title',
                    'body': msg,
                    'message': msg,
                    'for_role': selectedRole,
                    'category': 'system',
                    'is_read': false,
                    'read': false,
                  });

                  // Trigger phone system notification
                  await NotificationService.showSystemNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: '📢 $title',
                    body: msg,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notice broadcasted to all tenants!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  setState(() => _isLoading = true);
                  _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to broadcast: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllRead() async {
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_readPrefsKey)?.toSet() ?? <String>{};
      for (final item in _items) {
        readIds.add(item.id);
      }
      await prefs.setStringList(_readPrefsKey, readIds.toList());

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client
            .from('notifications')
            .update({'is_read': true, 'read': true})
            .eq('recipient_id', userId);
      }
    } catch (_) {}
  }

  Future<void> _markItemRead(_NotifItem item, int index) async {
    setState(() {
      _items[index] = item.copyWith(isRead: true);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_readPrefsKey)?.toSet() ?? <String>{};
      readIds.add(item.id);
      await prefs.setStringList(_readPrefsKey, readIds.toList());

      final client = Supabase.instance.client;
      await client
          .from('notifications')
          .update({'is_read': true, 'read': true})
          .eq('id', item.id);
    } catch (_) {}

    if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
      final uri = Uri.parse(item.actionUrl!);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    } else if (item.category == 'system' ||
        item.title.toLowerCase().contains('update') ||
        (item.body?.toLowerCase().contains('update') ?? false) ||
        (item.body?.toLowerCase().contains('apk') ?? false)) {
      if (mounted) UpdateService.checkForUpdates(context, isManual: true);
    }
  }

  Future<void> _dismissItem(_NotifItem item, int index) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _items.removeAt(index);
    });

    // Save permanently in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedIds = prefs.getStringList(_dismissedPrefsKey)?.toSet() ?? <String>{};
      dismissedIds.add(item.id);
      await prefs.setStringList(_dismissedPrefsKey, dismissedIds.toList());

      final client = Supabase.instance.client;
      await client.from('notifications').delete().eq('id', item.id);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed: "${item.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.amber,
          onPressed: () async {
            setState(() {
              _items.insert(index, item);
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              final dismissedIds = prefs.getStringList(_dismissedPrefsKey)?.toSet() ?? <String>{};
              dismissedIds.remove(item.id);
              await prefs.setStringList(_dismissedPrefsKey, dismissedIds.toList());
            } catch (_) {}
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).length;
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role == 'admin' && _userRole == 'admin';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Notifications', style: AppTextStyles.h2),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread',
                  style: AppTextStyles.captionBold.copyWith(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Broadcast notice',
              onPressed: _showBroadcastSheet,
            ),
            IconButton(
              icon: const Icon(Icons.notification_add_outlined),
              tooltip: 'Send test alert',
              onPressed: _sendTestAlert,
            ),
          ],
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_none_rounded,
                                  size: 56, color: AppColors.inkMuted),
                              const SizedBox(height: 16),
                              Text('No notifications', style: AppTextStyles.h3),
                              const SizedBox(height: 8),
                              Text('You\'re all caught up! Swipe down to refresh.',
                                  style: AppTextStyles.bodyRegular),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return Dismissible(
                          key: Key('notif-${item.id}'),
                          direction: DismissDirection.startToEnd, // Swipe right to remove
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: AppColors.error,
                            child: const Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Remove notification',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) => _dismissItem(item, i),
                          child: _NotifTile(
                            item: item,
                            onTap: () => _markItemRead(item, i),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item, required this.onTap});
  final _NotifItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? null : AppColors.actionBg.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _bgColor(item.category),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(item.category), size: 20, color: _iconColor(item.category)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: item.isRead
                              ? AppTextStyles.bodyMedium
                              : AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.action,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body!,
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: item.isRead ? AppColors.inkMuted : AppColors.ink,
                      ),
                    ),
                  ],
                  if (item.actionUrl != null && item.actionUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.actionBg,
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.action),
                      label: Text(
                        'Download Latest APK',
                        style: AppTextStyles.captionBold.copyWith(color: AppColors.action),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    item.timeAgo,
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String cat) {
    switch (cat.toLowerCase()) {
      case 'payment':
        return Icons.arrow_downward_rounded;
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'electricity':
        return Icons.bolt_rounded;
      case 'system':
        return Icons.campaign_rounded;
      case 'advance':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _bgColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'payment':
        return AppColors.successBg;
      case 'bill':
        return AppColors.errorBg;
      case 'electricity':
        return AppColors.warningBg;
      case 'system':
        return AppColors.actionBg;
      case 'advance':
        return const Color(0xFFEFF6FF);
      default:
        return AppColors.surface;
    }
  }

  Color _iconColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'payment':
        return AppColors.success;
      case 'bill':
        return AppColors.error;
      case 'electricity':
        return AppColors.warning;
      case 'system':
        return AppColors.action;
      case 'advance':
        return Colors.indigo;
      default:
        return AppColors.inkMuted;
    }
  }
}

class _NotifItem {
  final String id;
  final String category;
  final String title;
  final String? body;
  final String timeAgo;
  final bool isRead;
  final String? actionUrl;

  const _NotifItem({
    required this.id,
    required this.category,
    required this.title,
    this.body,
    required this.timeAgo,
    required this.isRead,
    this.actionUrl,
  });

  _NotifItem copyWith({
    String? id,
    String? category,
    String? title,
    String? body,
    String? timeAgo,
    bool? isRead,
    String? actionUrl,
  }) {
    return _NotifItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      timeAgo: timeAgo ?? this.timeAgo,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }
}
