// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Commands ─────────────────────────────────────────────────────────────────

Future<void> _cmdInit() async {
  _printHeader('Initializing SPL');

  if (!File('pubspec.yaml').existsSync()) {
    _die('pubspec.yaml not found. Run from the Flutter project root.');
  }

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(pubspec);
  if (nameMatch == null) _die('Could not read package name from pubspec.yaml.');
  final packageName = nameMatch.group(1)!.trim();

  final descMatch = RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(pubspec);
  final appName = descMatch?.group(1)?.trim() ?? packageName;

  // spl.yaml
  if (File('spl.yaml').existsSync()) {
    print('  ~  spl.yaml  (already exists, skipping)');
  } else {
    File('spl.yaml').writeAsStringSync(_tplSplYaml(appName, packageName));
    print('  +  spl.yaml');
  }

  // features_catalog/
  Directory('features_catalog').createSync(recursive: true);
  final gitkeep = File('features_catalog/.gitkeep');
  if (!gitkeep.existsSync()) gitkeep.writeAsStringSync('');
  print('  +  features_catalog/');

  // lib/core/storage/
  Directory('lib/core/storage/impl').createSync(recursive: true);

  const appStoragePath = 'lib/core/storage/app_storage.dart';
  if (!File(appStoragePath).existsSync()) {
    File(appStoragePath).writeAsStringSync(_tplAppStorage());
    print('  +  $appStoragePath');
  } else {
    print('  ~  $appStoragePath  (already exists, skipping)');
  }

  const storageModulePath = 'lib/core/storage/storage_module.dart';
  if (!File(storageModulePath).existsSync()) {
    _rewriteStorageModule(['flutter_secure_storage'], 'flutter_secure_storage');
    _generateStorageImpl('flutter_secure_storage');
  } else {
    print('  ~  $storageModulePath  (already exists, skipping)');
  }

  // analysis_options.yaml
  _ensureAnalysisExclusions();

  print('');
  print('  ✓ Done! Project initialized for SPL.');
  print('');
  print('  Add flutter_secure_storage to pubspec.yaml (if not already):');
  print('    flutter_secure_storage: ^9.0.0');
  print('');
  print('  Then scaffold your first feature:');
  print('    spl add <feature-name>');
  print('    spl list');
}

Future<void> _cmdList() async {
  final config = _readSplConfig();
  _printHeader('SPL Configuration');

  final storageDefault   = _getDefaultProviderName();
  final storageActive    = _getActiveProviders();
  final stateDefault     = config['state_management']?['default'] ?? 'bloc';

  print('  App              : ${config['app']?['name'] ?? 'unknown'}');
  print('  Storage [OR]     : ${storageActive.join(', ')} (default: $storageDefault)');
  print('  State Mgmt [OR]  : $stateDefault (default, per-feature override allowed)');
  print('');

  final features = config['features'] as List<Map<String, String>>? ?? [];
  if (features.isEmpty) {
    print('  No features yet.');
    print('    spl add <name>');
    return;
  }

  final active   = features.where((f) => (f['status'] ?? 'active') == 'active').toList();
  final inactive = features.where((f) => (f['status'] ?? 'active') == 'inactive').toList();

  print('  Active features  [compiled + DI-wired]:');
  if (active.isEmpty) {
    print('    (none)');
  } else {
    for (final f in active) {
      final name       = f['name'] ?? '?';
      final storage    = f['storage'] ?? 'none';
      final state      = f['state'] ?? stateDefault;
      final desc       = f['description'] ?? '';
      final storageTag = storage == 'none' ? '' : '  storage:$storage';
      print('  ✓  $name  state:$state$storageTag');
      if (desc.isNotEmpty && desc != '""') print('      $desc');
    }
  }

  if (inactive.isNotEmpty) {
    print('');
    print('  Catalog  [code preserved, not compiled]:');
    for (final f in inactive) {
      final name       = f['name'] ?? '?';
      final storage    = f['storage'] ?? 'none';
      final state      = f['state'] ?? stateDefault;
      final desc       = f['description'] ?? '';
      final storageTag = storage == 'none' ? '' : '  storage:$storage';
      print('  ○  $name  state:$state$storageTag');
      if (desc.isNotEmpty && desc != '""') print('      $desc');
    }
  }

  print('');
  print('  Tip: spl storage list');
  print('       spl state list');
}

Future<void> _cmdAdd(
  String name, {
  bool withStorage = false,
  String? storageOverride,
  bool withTest = false,
  bool shellRoute = false,
  String? stateOverride,
  bool runDi = true,
}) async {
  final module = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  final className = _toPascalCase(module);
  final featureDir = 'lib/features/$module';

  if (Directory(featureDir).existsSync()) {
    _die('Feature "$module" already exists at $featureDir');
  }
  if (Directory('features_catalog/$module').existsSync()) {
    _die('Feature "$module" exists in the catalog (disabled).\n'
        '  To restore it: spl enable $module\n'
        '  To delete it:  spl remove $module');
  }

  final config = _readSplConfig();
  final globalStateDefault = config['state_management']?['default'] ?? 'bloc';
  final stateChoice = stateOverride ?? globalStateDefault;
  _validateStateChoice(stateChoice);

  // Resolve effective storage provider
  String? storageProvider;
  if (storageOverride != null) {
    _validateStorageProvider(storageOverride);
    storageProvider = storageOverride;
  } else if (withStorage) {
    storageProvider = _getDefaultProviderName();
  }

  // Auto-register provider if not already active
  if (storageProvider != null) {
    await _ensureStorageActive(storageProvider);
  }

  _printHeader('Adding feature: $module');
  print('  Class   : $className');
  print('  Storage : ${storageProvider ?? 'none'}');
  print('  State   : $stateChoice${stateOverride != null ? ' (override)' : ' (default)'}');
  print('  Route   : ${shellRoute ? 'shell (bottom nav)' : 'top-level'}');
  print('  Tests   : ${withTest ? 'yes (--with-test)' : 'no'}');
  print('  DI      : auto-wired via build_runner (@injectable)');
  print('');

  final usedMason = await _tryMasonFeature(module,
      withStorage: storageProvider != null, state: stateChoice);
  if (!usedMason) {
    _generateFeatureFiles(module, className,
        storageProvider: storageProvider, state: stateChoice);
  }

  _addFeatureToConfig(
    module,
    storage: storageProvider ?? 'none',
    state: stateChoice,
  );

  _injectRoute(module, className, shellRoute: shellRoute);

  if (withTest) _generateTestFiles(module, className, state: stateChoice);

  _printStateNotes(stateChoice);

  if (runDi) {
    print('\n  Wiring DI (build_runner)...');
    await _runBuildRunner();
    print('\n  ✓ Done! lib/features/$module/');
  }
}

Future<void> _cmdDisable(String name, {bool runDi = true}) async {
  final module = name.toLowerCase();
  final activeDir  = 'lib/features/$module';
  final catalogDir = 'features_catalog/$module';

  _printHeader('Disabling feature: $module');

  if (!Directory(activeDir).existsSync()) {
    if (Directory(catalogDir).existsSync()) {
      _die('Feature "$module" is already disabled (in catalog).');
    }
    _die('Feature "$module" not found.');
  }

  // Cross-feature dependency check — warn only, don't block
  final deps = _checkCrossFeatureDeps(module);
  if (deps.isNotEmpty) {
    print('  ⚠  Other features reference "$module":');
    for (final entry in deps.entries) {
      print('     ${entry.key}');
      for (final line in entry.value) print('       $line');
    }
    print('  These references will break once "$module" is disabled. Fix them after.');
    print('');
  }

  Directory('features_catalog').createSync();
  Directory(activeDir).renameSync(catalogDir);
  print('  ○  Moved: $activeDir  →  $catalogDir');

  _removeRoute(module);
  _updateFeatureStatusInConfig(module, 'inactive');

  if (runDi) {
    print('  Regenerating DI...');
    await _runBuildRunner();
  }
  print('\n  ✓ Feature "$module" disabled.');
  print('  → Restore with: spl enable $module');
}

Future<void> _cmdEnable(String name, {bool runDi = true}) async {
  final module = name.toLowerCase();
  final activeDir  = 'lib/features/$module';
  final catalogDir = 'features_catalog/$module';

  _printHeader('Enabling feature: $module');

  if (!Directory(catalogDir).existsSync()) {
    if (Directory(activeDir).existsSync()) {
      _die('Feature "$module" is already active.');
    }
    _die('Feature "$module" not found in catalog.\n'
        '  Add it fresh: spl add $module');
  }

  Directory('lib/features').createSync(recursive: true);
  Directory(catalogDir).renameSync(activeDir);
  print('  ✓  Moved: $catalogDir  →  $activeDir');

  _updateFeatureStatusInConfig(module, 'active');

  if (runDi) {
    print('  Wiring DI (build_runner)...');
    await _runBuildRunner();
    print('\n  ✓ Feature "$module" enabled.');
    print('  → Ensure route is registered in lib/core/router/app_router_config.dart');
  } else {
    print('  ✓ Feature "$module" enabled.');
    print('  → Ensure route is registered in lib/core/router/app_router_config.dart');
  }
}

/// Returns true if the feature was active (DI regeneration needed).
Future<bool> _cmdRemove(String name, {bool force = false, bool runDi = true}) async {
  final module = name.toLowerCase();
  final activeDir  = 'lib/features/$module';
  final catalogDir = 'features_catalog/$module';

  final inActive  = Directory(activeDir).existsSync();
  final inCatalog = Directory(catalogDir).existsSync();

  if (!inActive && !inCatalog) _die('Feature "$module" not found.');

  final location = inActive ? activeDir : catalogDir;
  _printHeader('Removing feature: $module');
  print('  Location: $location${inCatalog ? ' (disabled)' : ' (active)'}');

  // Cross-feature dependency check — block if deps found and not forced
  final deps = _checkCrossFeatureDeps(module);
  if (deps.isNotEmpty) {
    print('  ⚠  Other features reference "$module":');
    for (final entry in deps.entries) {
      print('     ${entry.key}');
      for (final line in entry.value) print('       $line');
    }
    print('');
    if (!force) {
      _die('Cannot remove "$module" — other features depend on it.\n'
          '  Fix the references first, or use --yes to force the deletion anyway.');
    }
    print('  Forcing removal despite cross-feature references.');
    print('');
  }

  if (!force) {
    stdout.write('  Permanently delete "$module"? [y/N] ');
    final confirm = stdin.readLineSync()?.toLowerCase();
    if (confirm != 'y' && confirm != 'yes') { print('  Aborted.'); exit(0); }
  }

  Directory(location).deleteSync(recursive: true);
  print('  Deleted: $location');
  _removeRoute(module);
  _removeTests(module);
  _removeFeatureFromConfig(module);

  if (inActive && runDi) {
    print('  Regenerating DI...');
    await _runBuildRunner();
  }
  print('\n  ✓ Feature "$module" permanently removed.');

  return inActive;
}

// ─── Storage commands ─────────────────────────────────────────────────────────

Future<void> _cmdStorageAdd(String provider) async {
  _validateStorageProvider(provider);

  final activeProviders = _getActiveProviders();
  if (activeProviders.contains(provider)) {
    print('\n  Storage provider "$provider" is already active.');
    exit(0);
  }

  _printHeader('Adding storage provider: $provider');

  final usedMason = await _tryMasonStorage(provider);
  if (!usedMason) _generateStorageImpl(provider);

  final newProviders = [...activeProviders, provider];
  _addStorageToConfig(provider);
  _rewriteStorageModule(newProviders, _getDefaultProviderName());

  print('\n  Regenerating DI...');
  await _runBuildRunner();
  print('\n  ✓ Storage provider "$provider" added.');
  _printStorageNotes(provider);
}

Future<void> _cmdStorageRemove(String provider) async {
  _validateStorageProvider(provider);

  final activeProviders = _getActiveProviders();
  if (!activeProviders.contains(provider)) {
    _die('Provider "$provider" is not active.');
  }
  if (activeProviders.length == 1) {
    _die('Cannot remove the only active storage provider.');
  }

  // Check if any active features use this provider
  final config = _readSplConfig();
  final features = config['features'] as List<Map<String, String>>? ?? [];
  final dependents = features
      .where((f) => f['storage'] == provider && (f['status'] ?? 'active') == 'active')
      .toList();

  if (dependents.isNotEmpty) {
    print('');
    print('  ⚠  Active features use "$provider":');
    for (final f in dependents) print('     ${f['name']}');
    _die('\n  Cannot remove "$provider" — active features depend on it.\n'
        '  Migrate those features to another backend first.');
  }

  _printHeader('Removing storage provider: $provider');

  _deleteStorageImpl(provider);
  _removeStorageFromConfig(provider);

  final newProviders = activeProviders.where((p) => p != provider).toList();
  var newDefault = _getDefaultProviderName();
  if (newDefault == provider) {
    newDefault = newProviders.first;
    _updateStorageDefaultInConfig(newDefault);
    print('  ⚠  Default storage changed to "$newDefault"');
  }

  _rewriteStorageModule(newProviders, newDefault);

  print('\n  Regenerating DI...');
  await _runBuildRunner();
  print('\n  ✓ Storage provider "$provider" removed.');
}

void _cmdStorageDefault(String provider) {
  _validateStorageProvider(provider);

  final activeProviders = _getActiveProviders();
  if (!activeProviders.contains(provider)) {
    _die('Provider "$provider" is not active.\n'
        '  Add it first: spl storage add $provider');
  }

  _updateStorageDefaultInConfig(provider);
  _printHeader('Storage default → $provider');
  print('  New features using --with-storage will use: $provider');
  print('  Existing features are unchanged.');
}

void _cmdStorageList() {
  _printHeader('Storage Providers  [OR — multiple can be active simultaneously]');
  final activeProviders = _getActiveProviders();
  final defaultProvider = _getDefaultProviderName();

  final config = _readSplConfig();
  final features = config['features'] as List<Map<String, String>>? ?? [];

  final descriptions = {
    'flutter_secure_storage': 'Encrypted key-value. Strings only. Best for sensitive data.',
    'sqflite':                'SQLite (relational). Best for structured/queryable data.',
    'hive':                   'NoSQL box store. Fast reads. Best for object graphs.',
    'shared_preferences':     'Simple key-value. Non-encrypted. Best for user settings.',
  };

  for (final entry in descriptions.entries) {
    final p = entry.key;
    final isActive  = activeProviders.contains(p);
    final isDefault = p == defaultProvider;
    final tags = [
      if (isActive) 'active',
      if (isDefault) 'default',
    ];
    final tagStr = tags.isEmpty ? '' : '  ◀ ${tags.join(', ')}';
    print('  $p$tagStr');
    print('      ${entry.value}');
    if (isActive) {
      final users = features.where((f) => f['storage'] == p).map((f) => f['name']).toList();
      if (users.isNotEmpty) print('      Used by: ${users.join(', ')}');
    }
    print('');
  }

  print('  spl storage add <provider>');
  print('  spl storage remove <provider>');
  print('  spl storage default <provider>');
}

// ─── State commands ───────────────────────────────────────────────────────────

void _cmdStateSet(String solution) {
  _validateStateChoice(solution);
  _updateStateDefaultInConfig(solution);
  _printHeader('State Management Default → $solution');
  print('  Updated spl.yaml default.');
  print('  Existing features are unchanged.');
  print('  New features will use: $solution');
  _printStateNotes(solution);
}

void _cmdStateList() {
  _printHeader('State Management  [OR — global default + per-feature override]');
  final config = _readSplConfig();
  final current = config['state_management']?['default'] ?? 'bloc';

  final solutions = {
    'bloc': [
      'flutter_bloc (already in pubspec)',
      'Event + State + Bloc. Explicit event stream. Best for complex flows.',
      'Files: <name>_event.dart  <name>_state.dart  <name>_bloc.dart',
    ],
    'cubit': [
      'flutter_bloc (already in pubspec, same package as bloc)',
      'State + Cubit only. No event classes. Simpler, fewer files.',
      'Files: <name>_state.dart  <name>_cubit.dart',
    ],
    'riverpod': [
      'flutter_riverpod (add to pubspec if not present)',
      'Notifier + Provider. Different DI model. Bridges to get_it via di<T>().',
      'Files: <name>_state.dart  <name>_notifier.dart',
    ],
  };

  for (final e in solutions.entries) {
    final active = e.key == current ? '  ◀ default' : '';
    print('  ${e.key}$active');
    for (final line in e.value) print('      $line');
    print('');
  }

  print('  Change default : spl state set <solution>');
  print('  Per-feature    : spl add <name> --state <solution>');
  print('');
  print('  Note: bloc and cubit coexist freely (same package).');
  print('        riverpod requires flutter_riverpod in pubspec.yaml.');
}

Future<void> _cmdFix() async {
  _printHeader('Running build_runner');
  await _runBuildRunner();
  print('  ✓ Done');
}
