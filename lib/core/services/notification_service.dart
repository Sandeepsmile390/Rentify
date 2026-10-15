import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static bool _hasPrompted = false;

  /// Prompts the user for notification permissions on app launch.
  /// Works across Android (POST_NOTIFICATIONS) and Web (Notification.requestPermission).
  static Future<bool> initializeAndPrompt() async {
    if (_hasPrompted) return true;
    _hasPrompted = true;

    try {
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
      return res.isGranted;
    } catch (e) {
      debugPrint('Error in requestPermission: $e');
      return false;
    }
  }
}
