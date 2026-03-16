import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_storage.dart';

/// [AppStorage] backed by FlutterSecureStorage (encrypted on-device key-value).
/// Managed by spl_manager. To switch: dart run codegen/spl_manager.dart storage set <provider>
class SecureStorageProvider implements AppStorage {
  final FlutterSecureStorage _storage;
  const SecureStorageProvider(this._storage);

  @override
  Future<void> init() async {}

  @override
  Future<void> put(String key, dynamic value) async {
    await _storage.write(key: key, value: value.toString());
  }

  @override
  Future<T?> get<T>(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    if (T == int) return int.tryParse(value) as T?;
    if (T == double) return double.tryParse(value) as T?;
    if (T == bool) return (value == 'true') as T?;
    return value as T?;
  }

  @override
  Future<void> delete(String key) async => _storage.delete(key: key);

  @override
  Future<void> clear() async => _storage.deleteAll();

  @override
  Future<bool> contains(String key) async => _storage.containsKey(key: key);
}
