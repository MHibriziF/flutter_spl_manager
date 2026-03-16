import 'package:sqflite/sqflite.dart';
import '../app_storage.dart';

/// [AppStorage] backed by sqflite (SQLite relational DB).
/// Managed by spl_manager. To switch: dart run codegen/spl_manager.dart storage set <provider>
class SqfliteStorageProvider implements AppStorage {
  Database? _db;
  static const _table = 'kv_store';

  @override
  Future<void> init() async {
    final path = await getDatabasesPath();
    _db = await openDatabase(
      '$path/app_storage.db',
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE $_table (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
  }

  @override
  Future<void> put(String key, dynamic value) async {
    await _db!.insert(
      _table,
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<T?> get<T>(String key) async {
    final rows = await _db!.query(_table, where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String;
    if (T == int) return int.tryParse(raw) as T?;
    if (T == double) return double.tryParse(raw) as T?;
    if (T == bool) return (raw == 'true') as T?;
    return raw as T?;
  }

  @override
  Future<void> delete(String key) async =>
      _db!.delete(_table, where: 'key = ?', whereArgs: [key]);

  @override
  Future<void> clear() async => _db!.delete(_table);

  @override
  Future<bool> contains(String key) async {
    final rows = await _db!.query(_table, where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty;
  }
}
