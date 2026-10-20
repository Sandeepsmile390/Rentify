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
    defaultValue: 'https://hxzuxainrstkobczijdu.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4enV4YWlucnN0a29iY3ppamR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyODU3MjUsImV4cCI6MjA5Nzg2MTcyNX0.hibAy5snlSj7jBbwXoY6xFr6uI87hVpfg60nmb5ba7w',
  );

  /// App timezone for billing engine display (actual billing uses server tz).
  static const String appTimezone = 'Asia/Kolkata';

  /// Default per-unit electricity rate in paise (₹9.00 = 900 paise).
  static const int defaultElectricityRatePaise = 900;

  /// Build/version info (populated by CI).
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.2.0+5',
  );
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '5',
  );
}
