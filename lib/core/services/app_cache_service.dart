/// Simple in-memory caching service with Time-To-Live (TTL).
/// Prevents repetitive database queries when navigating between tabs.
class AppCacheService {
  static final Map<String, _CacheEntry> _cache = {};

  /// Default cache expiration: 3 minutes.
  static const Duration defaultTtl = Duration(minutes: 3);

  /// Retrieves cached data if still valid. Returns null if expired or missing.
  static T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Sets a value in the cache with an optional custom TTL.
  static void set<T>(String key, T value, [Duration ttl = defaultTtl]) {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
    );
  }

  /// Clears a specific cache key.
  static void invalidate(String key) {
    _cache.remove(key);
  }

  /// Clears all cached data (e.g., after recording payment, adding/deleting tenant, or pull-to-refresh).
  static void clearAll() {
    _cache.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiry;

  _CacheEntry({required this.value, required this.expiry});
}
