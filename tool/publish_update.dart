import 'dart:convert';
import 'dart:io';

/// Script to rebuild/publish APK, push to GitHub Apk repo,
/// and automatically broadcast update to every tenant and admin phone system tray.
Future<void> main(List<String> args) async {
  print('====================================================');
  print('  Rentify Automated APK Rebuild & Update Broadcast  ');
  print('====================================================');

  final bool skipBuild = args.contains('--skip-build');
  final bool bumpVersion = args.contains('--bump');

  // 1. Read current version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found. Run from project root.');
    exit(1);
  }

  var pubspecContent = await pubspecFile.readAsString();
  final versionRegex = RegExp(r'^version:\s*([^\s\r\n]+)', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);
  if (match == null) {
    print('Error: Could not parse version from pubspec.yaml');
    exit(1);
  }

  String currentVersion = match.group(1)!;
  String newVersion = currentVersion;

  if (bumpVersion) {
    if (currentVersion.contains('+')) {
      final parts = currentVersion.split('+');
      final semver = parts[0];
      final buildNum = (int.tryParse(parts[1]) ?? 0) + 1;
      newVersion = '$semver+$buildNum';
    } else {
      newVersion = '$currentVersion+1';
    }
    print('Bumping version: $currentVersion -> $newVersion');
    pubspecContent = pubspecContent.replaceFirst(
      'version: $currentVersion',
      'version: $newVersion',
    );
    await pubspecFile.writeAsString(pubspecContent);

    // Update env.dart
    final envFile = File('lib/core/config/env.dart');
    if (envFile.existsSync()) {
      var envContent = await envFile.readAsString();
      envContent = envContent.replaceAll(
        RegExp(r"defaultValue:\s*'1\.[0-9]+\.[0-9]+\+[0-9]+'"),
        "defaultValue: '$newVersion'",
      );
      await envFile.writeAsString(envContent);
    }
  }

  print('Target release version: v$newVersion');

  // 2. Build Release APK (unless skipped)
  final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
  if (!skipBuild) {
    print('\n[1/4] Compiling release APK (flutter build apk --release)...');
    final buildProcess = await Process.start(
      'flutter',
      ['build', 'apk', '--release'],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    final exitCode = await buildProcess.exitCode;
    if (exitCode != 0) {
      print('APK compilation failed with exit code $exitCode');
      exit(exitCode);
    }
  } else {
    print('\n[1/4] Skipping APK compilation (--skip-build requested)');
  }

  if (!apkFile.existsSync()) {
    print('Error: Release APK not found at ${apkFile.path}');
    exit(1);
  }

  final apkSizeBytes = await apkFile.length();
  final apkSizeMb = (apkSizeBytes / (1024 * 1024)).toStringAsFixed(2);
  print('Release APK verified: $apkSizeMb MB');

  // 3. Push APK to GitHub repository (https://github.com/Sandeepsmile390/Apk)
  print('\n[2/4] Uploading APK to https://github.com/Sandeepsmile390/Apk...');
  final tempDir = Directory.systemTemp.createTempSync('rentify_apk_publish_');
  final repoDir = Directory('${tempDir.path}/Apk');

  try {
    final cloneRes = await Process.run(
      'git',
      ['clone', '--depth', '1', 'https://github.com/Sandeepsmile390/Apk.git', repoDir.path],
      runInShell: true,
    );
    if (cloneRes.exitCode != 0) {
      throw Exception('Failed to clone Apk repo: ${cloneRes.stderr}');
    }

    final targetApk = File('${repoDir.path}/app-release.apk');
    await apkFile.copy(targetApk.path);

    await Process.run('git', ['-C', repoDir.path, 'add', 'app-release.apk'], runInShell: true);
    await Process.run(
      'git',
      ['-C', repoDir.path, 'commit', '-m', 'Release Rentify v$newVersion'],
      runInShell: true,
    );
    final pushRes = await Process.run(
      'git',
      ['-C', repoDir.path, 'push', 'origin', 'main'],
      runInShell: true,
    );
    if (pushRes.exitCode != 0) {
      throw Exception('Failed to push APK to origin main: ${pushRes.stderr}');
    }
    print('Successfully pushed APK to https://github.com/Sandeepsmile390/Apk on main');
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  const directApkUrl =
      'https://raw.githubusercontent.com/Sandeepsmile390/Apk/main/app-release.apk';

  // 4. Broadcast update to Supabase (system_settings & notifications)
  print('\n[3/4] Broadcasting update to Supabase realtime channel...');
  const supabaseUrl = 'https://hxzuxainrstkobczijdu.supabase.co';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4enV4YWlucnN0a29iY3ppamR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyODU3MjUsImV4cCI6MjA5Nzg2MTcyNX0.hibAy5snlSj7jBbwXoY6xFr6uI87hVpfg60nmb5ba7w';

  final httpClient = HttpClient();

  // Upsert system_settings
  final settingsPayload = jsonEncode([
    {
      'key': 'app_version',
      'value': newVersion,
      'description': 'Latest published Android APK version string',
    },
    {
      'key': 'apk_download_url',
      'value': directApkUrl,
      'description': 'Direct download link for release APK',
    },
    {
      'key': 'app_release_notes',
      'value': 'New release v$newVersion with enhanced performance, automatic system tray update notifications, and instant one-tap download & install.',
      'description': 'Changelog for latest version',
    },
  ]);

  final settingsReq = await httpClient.postUrl(
    Uri.parse('$supabaseUrl/rest/v1/system_settings'),
  );
  settingsReq.headers.set('apikey', anonKey);
  settingsReq.headers.set('Authorization', 'Bearer $anonKey');
  settingsReq.headers.set('Content-Type', 'application/json');
  settingsReq.headers.set('Prefer', 'resolution=merge-duplicates');
  settingsReq.add(utf8.encode(settingsPayload));
  final settingsRes = await settingsReq.close();
  final settingsBody = await utf8.decodeStream(settingsRes);
  print('Supabase system_settings updated: HTTP ${settingsRes.statusCode} $settingsBody');

  // Insert broadcast notification for all tenants and admin
  final notifId = 'update-${DateTime.now().millisecondsSinceEpoch}';
  final notifPayload = jsonEncode({
    'id': notifId,
    'title': '🚀 Rentify Update v$newVersion Available',
    'message': 'A new update is available! Tap below to download and install instantly.',
    'body': 'A new update is available! Tap below to download and install instantly.',
    'category': 'app_update',
    'for_role': 'all',
    'is_read': false,
    'read': false,
    'metadata': {
      'apk_url': directApkUrl,
      'version': newVersion,
    },
  });

  final notifReq = await httpClient.postUrl(
    Uri.parse('$supabaseUrl/rest/v1/notifications'),
  );
  notifReq.headers.set('apikey', anonKey);
  notifReq.headers.set('Authorization', 'Bearer $anonKey');
  notifReq.headers.set('Content-Type', 'application/json');
  notifReq.add(utf8.encode(notifPayload));
  final notifRes = await notifReq.close();
  final notifBody = await utf8.decodeStream(notifRes);
  print('Supabase broadcast notification sent: HTTP ${notifRes.statusCode} $notifBody');

  httpClient.close();

  print('\n[4/4] Verification & Broadcast Complete!');
  print('----------------------------------------------------');
  print('Version: $newVersion');
  print('Direct APK Download URL: $directApkUrl');
  print('Status: Broadcast sent to all admin & tenant devices.');
  print('Devices running Rentify will immediately receive the system tray');
  print('notification with "Download & Install" action button.');
  print('====================================================');
}
