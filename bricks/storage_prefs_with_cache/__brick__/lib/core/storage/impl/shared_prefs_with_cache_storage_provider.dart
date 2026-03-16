import 'package:shared_preferences/shared_preferences.dart';
import '../app_storage.dart';

/// [AppStorage] backed by SharedPreferencesWithCache (non-encrypted key-value).
/// Reads are served from an in-memory cache; writes go through to disk.
/// Managed by spl_manager. To switch: spl storage default <provider>
/// Requires: shared_preferences: ^2.3.0 in pubspec.yaml
/// Call di<AppStorage>().init() in main() before runApp().
class SharedPrefsWithCacheStorageProvider implements AppStorage {
  late SharedPreferencesWithCache _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  }

  @override
  Future<void> put(String key, dynamic value) async {
    if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else {
      await _prefs.setString(key, value.toString());
    }
  }

  @override
  Future<T?> get<T>(String key) async => _prefs.get(key) as T?;

  @override
  Future<void> delete(String key) async => _prefs.remove(key);

  @override
  Future<void> clear() async => _prefs.clear();

  @override
  Future<bool> contains(String key) async => _prefs.containsKey(key);
}
