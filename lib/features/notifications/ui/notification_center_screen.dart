import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_chip.dart';

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
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _items = _NotifItem.placeholders();
    });
  }

  void _markAllRead() {
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    });
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

  static List<_NotifItem> placeholders() => [
    const _NotifItem(id: 'n1', category: 'payment', title: 'Payment recorded', body: '₹6,850 received from Priya Sharma (Room 07)', timeAgo: '2 min ago', isRead: false),
    const _NotifItem(id: 'n2', category: 'charge', title: 'Monthly billing complete', body: 'October 2026 charges generated for 28 tenants', timeAgo: '1 hour ago', isRead: false),
    const _NotifItem(id: 'n3', category: 'meter', title: 'Meter reading awaited', body: '3 tenants still need October meter readings', timeAgo: '3 hours ago', isRead: true),
    const _NotifItem(id: 'n4', category: 'payment', title: 'Payment recorded', body: '₹5,500 received from Manoj Kumar (Room 03)', timeAgo: 'Yesterday', isRead: true),
  ];
}
