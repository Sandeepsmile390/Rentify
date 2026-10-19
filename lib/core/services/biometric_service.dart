import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();
  static const _prefKey = 'rentify_biometric_enabled';

  /// Check whether the current platform supports biometric / device credential authentication.
  static Future<bool> isPlatformSupported() async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Get the saved preference from secure storage.
  static Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    try {
      final val = await _storage.read(key: _prefKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Enable or disable biometric unlock. Enabling requires a successful system authentication.
  static Future<bool> setBiometricEnabled(bool enabled) async {
    if (kIsWeb) return false;

    if (enabled) {
      final authenticated = await authenticate(
        reason: 'Verify biometric identity to enable quick unlock for Rentify',
      );
      if (!authenticated) return false;
    }

    try {
      await _storage.write(key: _prefKey, value: enabled ? 'true' : 'false');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Perform system biometric or device credential authentication.
  static Future<bool> authenticate({
    String reason = 'Authenticate to access Rentify',
  }) async {
    if (kIsWeb) return true;
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return true;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
