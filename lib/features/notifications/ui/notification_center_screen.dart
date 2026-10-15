import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';
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

      var query = client.from('notifications').select('*');
      if (userId != null) {
        query = query.eq('recipient_id', userId);
      }
      final res = await query.order('created_at', ascending: false);

      final rows = res as List<dynamic>;
      final list = rows.map((r) {
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

        return _NotifItem(
          id: (r['id'] as String?) ?? '',
          category: (r['category'] as String?) ?? 'system',
          title: (r['title'] as String?) ?? 'Notification',
          body: (r['body'] as String?) ?? '',
          timeAgo: timeAgo,
          isRead: (r['is_read'] as bool?) ?? false,
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
      if (userId == null) return;

      await client.from('notifications').insert({
        'recipient_id': userId,
        'category': 'payment',
        'title': 'Test Notification Alert',
        'body': 'Popup notifications and alerts are successfully enabled in Rentify!',
        'is_read': false,
      });

      // Request or verify permission
      await NotificationService.requestPermission();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent and permission active!'),
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
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 56, color: AppColors.inkMuted),
                      const SizedBox(height: 16),
                      Text('No notifications', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text('You\'re all caught up!',
                          style: AppTextStyles.bodyRegular),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) => _NotifTile(
                    item: _items[i],
                    onTap: () {
                      setState(() {
                        _items[i] = _items[i].copyWith(isRead: true);
                      });
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
        color: item.isRead ? null : AppColors.actionBg.withOpacity(0.3),
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
    _ => Icons.notifications_outlined,
  };

  Color _bgColor(String cat) => switch (cat) {
    'payment' => AppColors.successBg,
    'charge' => AppColors.actionBg,
    'meter' => AppColors.warningBg,
    _ => AppColors.surfaceVariant,
  };

  Color _iconColor(String cat) => switch (cat) {
    'payment' => AppColors.success,
    'charge' => AppColors.action,
    'meter' => AppColors.warning,
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
