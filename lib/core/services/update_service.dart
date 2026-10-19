import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class UpdateService {
  static const String currentAppVersion = '1.1.0+2';
  static bool _hasPromptedThisSession = false;

  /// Checks if a newer version exists in Supabase system_settings
  static Future<void> checkForUpdates(BuildContext context, {bool isManual = false}) async {
    if (!kIsWeb && !isManual && _hasPromptedThisSession) return;

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('system_settings')
          .select('key, value')
          .inFilter('key', ['app_version', 'apk_download_url', 'app_release_notes']);

      final Map<String, String> settings = {};
      for (final r in (res as List<dynamic>)) {
        settings[r['key'].toString()] = r['value']?.toString() ?? '';
      }

      final latestVer = settings['app_version'] ?? currentAppVersion;
      final apkUrl = settings['apk_download_url'] ??
          'https://github.com/Sandeepsmile390/Rentify/raw/main/build/app/outputs/flutter-apk/app-release.apk';
      final notes = settings['app_release_notes'] ?? 'General performance improvements and bug fixes.';

      if (_isNewerVersion(latestVer, currentAppVersion)) {
        _hasPromptedThisSession = true;
        if (context.mounted) {
          _showUpdateDialog(context, latestVer, apkUrl, notes);
        }
      } else if (isManual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are on the latest version ($currentAppVersion).'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (isManual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check for updates. Please check network connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty || latest == current) return false;
    try {
      final latestClean = latest.split('+').first.replaceAll(RegExp(r'[^\d.]'), '');
      final currentClean = current.split('+').first.replaceAll(RegExp(r'[^\d.]'), '');

      final lParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < lParts.length && i < cParts.length; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }

      // Check build number if semantic versions are identical
      final lBuild = int.tryParse(latest.contains('+') ? latest.split('+').last : '0') ?? 0;
      final cBuild = int.tryParse(current.contains('+') ? current.split('+').last : '0') ?? 0;
      return lBuild > cBuild;
    } catch (_) {
      return latest != current;
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String latestVer,
    String apkUrl,
    String notes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.actionBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: AppColors.action),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Update Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version ($latestVer) is available to install.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                notes,
                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dCtx);
              await downloadAndInstallApk(context, apkUrl);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Update & Install'),
          ),
        ],
      ),
    );
  }

  /// Downloads and triggers APK installation
  static Future<void> downloadAndInstallApk(BuildContext context, String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open update link: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Broadcasts a new update version to system_settings and sends notification to everyone
  static Future<bool> broadcastUpdate({
    required String version,
    required String apkUrl,
    required String notes,
  }) async {
    try {
      final client = Supabase.instance.client;
      // 1. Update system_settings
      await client.from('system_settings').upsert([
        {'key': 'app_version', 'value': version},
        {'key': 'apk_download_url', 'value': apkUrl},
        {'key': 'app_release_notes', 'value': notes},
      ], onConflict: 'key');

      // 2. Broadcast notification to all users
      await client.from('notifications').insert({
        'id': 'update-${DateTime.now().millisecondsSinceEpoch}',
        'for_role': 'all',
        'category': 'system',
        'title': 'New Rentify Update v$version Available',
        'body': notes,
        'message': notes,
        'is_read': false,
        'read': false,
      });

      return true;
    } catch (e) {
      debugPrint('Failed to broadcast update: $e');
      return false;
    }
  }
}
