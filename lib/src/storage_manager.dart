// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Storage impl management ──────────────────────────────────────────────────

const _validProviders = [
  'flutter_secure_storage',
  'sqflite',
  'hive',
  'shared_preferences',
];

void _validateStorageProvider(String provider) {
  if (!_validProviders.contains(provider)) {
    _die('Unknown provider: "$provider"\nValid: ${_validProviders.join(' | ')}');
  }
}

String _getDefaultProviderName() {
  final config = _readSplConfig();
  return config['storage']?['default'] as String?
      ?? config['storage']?['local_backend'] as String? // backward compat
      ?? 'flutter_secure_storage';
}

List<String> _getActiveProviders() {
  final config = _readSplConfig();
  final raw = config['storage']?['active'] as String?
      ?? config['storage']?['local_backend'] as String? // backward compat
      ?? 'flutter_secure_storage';
  return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

String _implFileName(String provider) => switch (provider) {
  'flutter_secure_storage' => 'secure_storage_provider.dart',
  'sqflite'                => 'sqflite_storage_provider.dart',
  'hive'                   => 'hive_storage_provider.dart',
  'shared_preferences'     => 'shared_prefs_storage_provider.dart',
  _                        => _die('Unknown provider: $provider'),
};

String _implFilePath(String p) => 'lib/core/storage/impl/${_implFileName(p)}';

void _deleteStorageImpl(String provider) {
  final path = _implFilePath(provider);
  if (File(path).existsSync()) {
    File(path).deleteSync();
    print('  -  $path  (removed)');
  }
}

void _generateStorageImpl(String provider) {
  final path = _implFilePath(provider);
  File(path).writeAsStringSync(_storageImplContent(provider));
  print('  +  $path  (generated)');
}

String _storageImplContent(String provider) => switch (provider) {
  'flutter_secure_storage' => _tplSecureStorageProvider(),
  'sqflite'                => _tplSqfliteProvider(),
  'hive'                   => _tplHiveProvider(),
  'shared_preferences'     => _tplSharedPrefsProvider(),
  _                        => _die('Unknown provider: $provider'),
};

/// Ensures [provider] is in the active list and has an impl file.
/// Does NOT run build_runner — caller is responsible for that.
Future<void> _ensureStorageActive(String provider) async {
  final activeProviders = _getActiveProviders();
  if (activeProviders.contains(provider)) return;

  print('  Auto-adding storage provider: $provider');

  if (!File(_implFilePath(provider)).existsSync()) {
    final usedMason = await _tryMasonStorage(provider);
    if (!usedMason) _generateStorageImpl(provider);
  }

  final newProviders = [...activeProviders, provider];
  _addStorageToConfig(provider);
  _rewriteStorageModule(newProviders, _getDefaultProviderName());
}

String _getterName(String provider) => switch (provider) {
  'flutter_secure_storage' => 'flutterSecureStorage',
  'sqflite'                => 'sqflite',
  'hive'                   => 'hive',
  'shared_preferences'     => 'sharedPreferences',
  _                        => _die('Unknown provider: $provider'),
};

String _providerConstructor(String provider) => switch (provider) {
  'flutter_secure_storage' => 'const SecureStorageProvider(FlutterSecureStorage())',
  'sqflite'                => 'SqfliteStorageProvider()',
  'hive'                   => 'HiveStorageProvider()',
  'shared_preferences'     => 'SharedPrefsStorageProvider()',
  _                        => _die('Unknown provider: $provider'),
};

void _rewriteStorageModule(List<String> providers, String defaultProvider) {
  final importLines = <String>[];
  if (providers.contains('flutter_secure_storage')) {
    importLines.add("import 'package:flutter_secure_storage/flutter_secure_storage.dart';");
    importLines.add("import 'impl/secure_storage_provider.dart';");
  }
  if (providers.contains('sqflite'))
    importLines.add("import 'impl/sqflite_storage_provider.dart';");
  if (providers.contains('hive'))
    importLines.add("import 'impl/hive_storage_provider.dart';");
  if (providers.contains('shared_preferences'))
    importLines.add("import 'impl/shared_prefs_storage_provider.dart';");

  final getters = providers.map((p) =>
    "  @lazySingleton\n"
    "  @Named('$p')\n"
    "  AppStorage get ${_getterName(p)} => ${_providerConstructor(p)};"
  ).join('\n\n');

  const path = 'lib/core/storage/storage_module.dart';
  File(path).writeAsStringSync(
'''// ============================================================
// SPL MANAGED FILE — DO NOT EDIT MANUALLY
// Active providers: ${providers.join(', ')}
// Default: $defaultProvider
// To manage: spl storage add|remove|default
// ============================================================

${importLines.join('\n')}

import 'package:injectable/injectable.dart';
import 'app_storage.dart';

@module
abstract class StorageModule {
$getters
}
''');
  print('  ~  lib/core/storage/storage_module.dart  (updated)');
}
