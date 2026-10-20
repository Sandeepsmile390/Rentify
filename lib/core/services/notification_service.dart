import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  final payload = notificationResponse.payload;
  if (payload != null && payload.isNotEmpty) {
    try {
      launchUrl(Uri.parse(payload), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class NotificationService {
  static bool _hasPrompted = false;
  static bool _isLocalNotificationsInitialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Prompts the user for notification permissions on app launch and initializes local notification channels.
  /// Works across Android (POST_NOTIFICATIONS) and Web.
  static Future<bool> initializeAndPrompt() async {
    if (_hasPrompted) return true;
    _hasPrompted = true;

    try {
      if (!kIsWeb) {
        await _initPlugin();
      }

      if (kIsWeb) {
        final status = await Permission.notification.request();
        debugPrint('Web notification permission status: $status');
        return status.isGranted;
      } else {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final res = await Permission.notification.request();
          debugPrint('Mobile notification permission status: $res');
          return res.isGranted;
        }
        return true;
      }
    } catch (e) {
      debugPrint('Notice requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> _initPlugin() async {
    if (_isLocalNotificationsInitialized || kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final uri = Uri.parse(payload);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('Error launching notification payload URL: $e');
            }
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final uri = Uri.parse(payload);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Error launching notification launch payload URL: $e');
          }
        }
      }
      _isLocalNotificationsInitialized = true;
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
  }

  /// Displays an actionable notification on the phone's notification panel / shade.
  static Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_isLocalNotificationsInitialized) {
        await _initPlugin();
      }

      final isUpdate = payload != null &&
          (payload.endsWith('.apk') ||
              payload.contains('raw.githubusercontent.com') ||
              payload.contains('drive.google.com') ||
              title.toLowerCase().contains('update'));

      // Ensure permission is granted on Android 13+
      await initializeAndPrompt();

      final androidDetails = AndroidNotificationDetails(
        'rentify_live_alerts_v2',
        'Rentify Live Alerts & Notices',
        channelDescription: 'Heads-up popups, updates, dues reminders, and billing receipts',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        ticker: 'Rentify Alert',
        actions: isUpdate
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'download_install_action',
                  'Download & Install',
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ]
            : null,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show system notification: $e');
    }
  }

  /// Checks if notification permission is currently granted.
  static Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Manually trigger permission request (e.g. from Settings).
  static Future<bool> requestPermission() async {
    try {
      final res = await Permission.notification.request();
      if (res.isGranted && !kIsWeb) {
        await _initPlugin();
      }
      return res.isGranted;
    } catch (e) {
      debugPrint('Error in requestPermission: $e');
      return false;
    }
  }

  /// Checks for new live notifications from Supabase and pops heads-up alerts.
  /// Runs safely in background execution even when the app is closed.
  static Future<void> checkBackgroundNotifications() async {
    if (kIsWeb) return;
    try {
      await _initPlugin();

      if (!Supabase.instance.isInitialized) {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          anonKey: Env.supabaseAnonKey,
        );
      }

      final client = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final notifiedIds = prefs.getStringList('rentify_notified_bg_ids') ?? [];

      // Query latest notifications
      final res = await client
          .from('notifications')
          .select('id, title, message, body, metadata')
          .order('created_at', ascending: false)
          .limit(5);

      for (final n in (res as List<dynamic>)) {
        final id = (n['id'] as String?) ?? '';
        if (id.isEmpty || notifiedIds.contains(id)) continue;

        final title = (n['title'] as String?) ?? 'Rentify Alert';
        final body = (n['message'] as String?) ?? (n['body'] as String?) ?? '';
        final metadata = n['metadata'] as Map<String, dynamic>?;
        final payload = metadata?['apk_url'] as String?;

        await showSystemNotification(
          id: id.hashCode,
          title: title,
          body: body,
          payload: payload,
        );

        notifiedIds.add(id);
      }

      if (notifiedIds.length > 50) {
        notifiedIds.removeRange(0, notifiedIds.length - 50);
      }
      await prefs.setStringList('rentify_notified_bg_ids', notifiedIds);
    } catch (e) {
      debugPrint('Background notification check error: $e');
    }
  }
}
