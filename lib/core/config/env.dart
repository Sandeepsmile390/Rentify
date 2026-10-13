/// Compile-time environment configuration.
/// Pass values via --dart-define when building:
///   flutter build web --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///                     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// NEVER hard-code real credentials here.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  /// App timezone for billing engine display (actual billing uses server tz).
  static const String appTimezone = 'Asia/Kolkata';

  /// Default per-unit electricity rate in paise (₹9.00 = 900 paise).
  static const int defaultElectricityRatePaise = 900;

  /// Build/version info (populated by CI).
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '1',
  );
}
