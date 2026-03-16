import 'package:hive_flutter/hive_flutter.dart';
import '../app_storage.dart';

/// [AppStorage] backed by Hive (fast NoSQL box store).
/// Managed by spl_manager. To switch: dart run codegen/spl_manager.dart storage set <provider>
/// Requires: hive_flutter: ^1.1.0 in pubspec.yaml
/// Call di<AppStorage>().init() in main() before runApp().
class HiveStorageProvider implements AppStorage {
  late Box _box;
  static const _boxName = 'app_storage';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  @override
  Future<void> put(String key, dynamic value) async => _box.put(key, value);

  @override
  Future<T?> get<T>(String key) async => _box.get(key) as T?;

  @override
  Future<void> delete(String key) async => _box.delete(key);

  @override
  Future<void> clear() async => _box.clear();

  @override
  Future<bool> contains(String key) async => _box.containsKey(key);
}
