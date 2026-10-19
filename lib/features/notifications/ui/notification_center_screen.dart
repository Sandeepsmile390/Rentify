import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Notification center — for both admin (all notifications) and tenant (own)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  bool _isLoading = true;
  List<_NotifItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

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
          .order('created_at', ascending: false)
          .limit(50);

      final rows = res as List<dynamic>;
      final list = rows.where((r) {
        if (userRole == 'admin') return true;
        final forRole = (r['for_role'] as String?)?.toLowerCase();
        final rId = r['recipient_id'] as String?;
        return forRole == 'tenant' || forRole == 'all' || rId == userId || forRole == null;
      }).map((r) {
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

        return _NotifItem(
          id: (r['id'] as String?) ?? '',
          category: (r['category'] as String?) ?? 'system',
          title: rawTitle,
          body: rawBody,
          timeAgo: timeAgo,
          isRead: (r['is_read'] as bool?) ?? (r['read'] as bool?) ?? false,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
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
        'title': 'Test Notification Alert',
        'body': 'Popup notifications and alerts are successfully enabled in Rentify!',
        'message': 'Popup notifications and alerts are successfully enabled in Rentify!',
        'is_read': false,
        'read': false,
      });

      // Request or verify permission
      await NotificationService.requestPermission();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent and alerts active!'),
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
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client
            .from('notifications')
            .update({'is_read': true})
            .eq('recipient_id', userId);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).length;

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
                          key: Key(item.id),
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
                          onDismissed: (direction) async {
                            final removedItem = item;
                            final removedIndex = i;
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _items.removeAt(removedIndex);
                            });

                            try {
                              await Supabase.instance.client
                                  .from('notifications')
                                  .delete()
                                  .eq('id', removedItem.id);
                            } catch (_) {}

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed: "${removedItem.title}"'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: Colors.amber,
                                    onPressed: () async {
                                      setState(() {
                                        _items.insert(removedIndex, removedItem);
                                      });
                                      try {
                                        await Supabase.instance.client
                                            .from('notifications')
                                            .insert({
                                          'id': removedItem.id,
                                          'title': removedItem.title,
                                          'body': removedItem.body,
                                          'category': removedItem.category,
                                          'is_read': removedItem.isRead,
                                        });
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: _NotifTile(
                            item: item,
                            onTap: () {
                              setState(() {
                                _items[i] = item.copyWith(isRead: true);
                              });
                              if (item.category == 'system' ||
                                  item.title.toLowerCase().contains('update') ||
                                  (item.body?.toLowerCase().contains('update') ?? false) ||
                                  (item.body?.toLowerCase().contains('apk') ?? false)) {
                                UpdateService.checkForUpdates(context, isManual: true);
                              }
                            },
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
        color: item.isRead ? null : AppColors.actionBg.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _bgColor(item.category),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(_icon(item.category), size: 18, color: _iconColor(item.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.title,
                            style: item.isRead
                                ? AppTextStyles.bodyRegular
                                : AppTextStyles.bodyMedium),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.action,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (item.body != null) ...[
                    const SizedBox(height: 2),
                    Text(item.body!,
                        style: AppTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(item.timeAgo, style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String cat) => switch (cat) {
    'payment' => Icons.payments_outlined,
    'charge' => Icons.receipt_outlined,
    'meter' => Icons.electric_meter_outlined,
    'system' => Icons.system_update_rounded,
    _ => Icons.notifications_outlined,
  };

  Color _bgColor(String cat) => switch (cat) {
    'payment' => AppColors.successBg,
    'charge' => AppColors.actionBg,
    'meter' => AppColors.warningBg,
    'system' => AppColors.actionBg,
    _ => AppColors.surfaceVariant,
  };

  Color _iconColor(String cat) => switch (cat) {
    'payment' => AppColors.success,
    'charge' => AppColors.action,
    'meter' => AppColors.warning,
    'system' => AppColors.action,
    _ => AppColors.inkMuted,
  };
}

class _NotifItem {
  final String id, category, title, timeAgo;
  final String? body;
  final bool isRead;

  const _NotifItem({
    required this.id, required this.category, required this.title,
    required this.timeAgo, this.body, this.isRead = false,
  });

  _NotifItem copyWith({bool? isRead}) => _NotifItem(
    id: id, category: category, title: title, timeAgo: timeAgo,
    body: body, isRead: isRead ?? this.isRead,
  );
}
