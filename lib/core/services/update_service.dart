import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class UpdateService {
  static const String currentAppVersion = '1.1.0+3';
  static const String defaultApkUrl =
      'https://drive.google.com/file/d/17iyA3iucFCk4YTtYbj_X_HpyYXS8C_zx/view?usp=sharing';

  /// Broadcasts an app update across all tenants and landlords
  static Future<bool> broadcastUpdate({
    required String version,
    required String apkUrl,
    required String notes,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('system_settings').upsert([
        {'key': 'app_version', 'value': version},
        {'key': 'apk_download_url', 'value': apkUrl},
        {'key': 'app_release_notes', 'value': notes},
      ], onConflict: 'key');

      // Create live broadcast notification in notifications table
      await client.from('notifications').insert({
        'title': 'New Update v$version Available',
        'message': notes.isNotEmpty
            ? notes
            : 'A new update is available. Download and install now for the latest features and bug fixes.',
        'type': 'app_update',
        'is_read': false,
        'metadata': {'apk_url': apkUrl, 'version': version},
      });

      return true;
    } catch (e) {
      debugPrint('Error broadcasting update: $e');
      return false;
    }
  }

  /// Checks if a newer version exists in Supabase system_settings
  static Future<void> checkForUpdates(BuildContext context, {bool isManual = false}) async {
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
      final apkUrl = (settings['apk_download_url'] != null && settings['apk_download_url']!.isNotEmpty)
          ? settings['apk_download_url']!
          : defaultApkUrl;
      final notes = settings['app_release_notes'] ?? 'General performance improvements and bug fixes.';

      if (_isNewerVersion(latestVer, currentAppVersion)) {
        // Broadcast app update: only show modal popup once per version
        final prefs = await SharedPreferences.getInstance();
        final promptedKey = 'has_shown_update_popup_$latestVer';
        final hasShownPopup = prefs.getBool(promptedKey) ?? false;

        if (isManual || !hasShownPopup) {
          await prefs.setBool(promptedKey, true);
          if (context.mounted) {
            _showUpdateDialog(context, latestVer, apkUrl, notes);
          }
        }
      } else if (isManual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
      barrierDismissible: true,
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
            const SizedBox(height: 8),
            Text(
              'You can also find this update anytime in your Alerts tab.',
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
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
            label: const Text('Download & Update'),
          ),
        ],
      ),
    );
  }

  /// Downloads and triggers APK installation
  static Future<void> downloadAndInstallApk(BuildContext context, String apkUrl) async {
    final uri = Uri.parse(apkUrl.isNotEmpty ? apkUrl : defaultApkUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open APK download link: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
