// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Feature file generation ──────────────────────────────────────────────────

void _generateFeatureFiles(
  String module,
  String className, {
  String? storageProvider,
  String state = 'bloc',
}) {
  final dirs = [
    'lib/features/$module/data/local',
    'lib/features/$module/data/model/mapper',
    'lib/features/$module/data/model/responses',
    'lib/features/$module/data/remote',
    'lib/features/$module/domain/model',
    'lib/features/$module/domain/repository',
    'lib/features/$module/domain/use_cases',
    if (state == 'riverpod')
      'lib/features/$module/presentation/providers'
    else
      'lib/features/$module/presentation/blocs',
    'lib/features/$module/presentation/pages',
    'lib/features/$module/presentation/widgets',
  ];
  for (final d in dirs) Directory(d).createSync(recursive: true);

  final files = <String, String>{
    // Data layer
    'lib/features/$module/data/local/${module}_local_data_sources.dart':
        _tplLocalDataSources(module, className, storageProvider: storageProvider),
    'lib/features/$module/data/model/mapper/${module}_mapper.dart':
        _tplMapper(module, className),
    'lib/features/$module/data/model/responses/${module}_response.dart':
        _tplResponse(module, className),
    'lib/features/$module/data/remote/${module}_remote_data_sources.dart':
        _tplRemoteDataSources(module, className),
    'lib/features/$module/data/${module}_repository_impl.dart':
        _tplRepositoryImpl(module, className),
    // Domain layer
    'lib/features/$module/domain/model/$module.dart': _tplModel(className),
    'lib/features/$module/domain/repository/${module}_repository.dart':
        _tplRepository(module, className),
    'lib/features/$module/domain/use_cases/${module}_use_cases.dart':
        _tplUseCases(module, className),
    'lib/features/$module/domain/${module}_interactor.dart':
        _tplInteractor(module, className),
    // Presentation — page (always the same)
    'lib/features/$module/presentation/pages/${module}_page.dart':
        _tplPage(module, className),
  };

  // Presentation — state management varies
  files.addAll(_stateFiles(module, className, state));

  for (final e in files.entries) {
    File(e.key).writeAsStringSync(e.value);
    print('  +  ${e.key}');
  }
}

Map<String, String> _stateFiles(String module, String className, String state) {
  switch (state) {
    case 'cubit':
      return {
        'lib/features/$module/presentation/blocs/${module}_state.dart':
            _tplState(className),
        'lib/features/$module/presentation/blocs/${module}_cubit.dart':
            _tplCubit(module, className),
      };
    case 'riverpod':
      return {
        'lib/features/$module/presentation/providers/${module}_state.dart':
            _tplState(className),
        'lib/features/$module/presentation/providers/${module}_notifier.dart':
            _tplRiverpodNotifier(module, className),
      };
    default: // bloc
      return {
        'lib/features/$module/presentation/blocs/${module}_event.dart':
            _tplEvent(className),
        'lib/features/$module/presentation/blocs/${module}_state.dart':
            _tplState(className),
        'lib/features/$module/presentation/blocs/${module}_bloc.dart':
            _tplBloc(module, className),
      };
  }
}

// ─── Cross-feature dependency check ──────────────────────────────────────────

/// Scans active features and tests for any imports/references to [module].
/// Returns a map of { filePath → [matching lines] } for all referencing files.
Map<String, List<String>> _checkCrossFeatureDeps(String module) {
  final pattern = 'features/$module/';
  final results = <String, List<String>>{};

  for (final root in ['lib/features', 'test/features']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      // Skip the module's own files
      if (normalized.contains('/$module/')) continue;
      final lines = entity.readAsLinesSync();
      final matches = lines.where((l) => l.contains(pattern)).map((l) => l.trim()).toList();
      if (matches.isNotEmpty) results[normalized] = matches;
    }
  }

  return results;
}

// ─── Route injection ──────────────────────────────────────────────────────────

void _injectRoute(String module, String className, {bool shellRoute = false}) {
  const routerPath = 'lib/core/router/app_router_config.dart';
  if (!File(routerPath).existsSync()) {
    print('  ⚠  Router not found at $routerPath — skipping route injection.');
    print('     Register the route manually.');
    return;
  }

  var content = File(routerPath).readAsStringSync();
  final pageImport =
      "import 'package:$_pkg/features/$module/presentation/pages/${module}_page.dart';";

  if (content.contains('${className}Page.route')) {
    print('  ~  Route for $className already exists — skipping.');
    return;
  }

  // Add import — insert before 'import package:flutter'
  content = content.replaceFirst(
    "import 'package:flutter/",
    "$pageImport\nimport 'package:flutter/",
  );

  if (shellRoute) {
    // Find the last GoRoute inside ShellRoute and append after it
    const anchor = "builder: (context, state) => const ProfilePage())";
    final newEntry = "\n          GoRoute(\n"
        "              path: ${className}Page.route,\n"
        "              name: ${className}Page.route,\n"
        "              parentNavigatorKey: _shellKey,\n"
        "              pageBuilder: (context, state) =>\n"
        "                  const NoTransitionPage(child: ${className}Page()),\n"
        "              builder: (context, state) => const ${className}Page())";
    content = content.replaceFirst(anchor, '$anchor$newEntry');
  } else {
    // Insert top-level GoRoute before ShellRoute(
    const anchor = '      ShellRoute(';
    final newEntry = "      GoRoute(\n"
        "          path: ${className}Page.route,\n"
        "          name: ${className}Page.route,\n"
        "          builder: (context, state) => const ${className}Page()),\n";
    content = content.replaceFirst(anchor, '$newEntry      ShellRoute(');
  }

  File(routerPath).writeAsStringSync(content);
  print('  ~  lib/core/router/app_router_config.dart  (route injected)');
}

void _removeRoute(String module) {
  const routerPath = 'lib/core/router/app_router_config.dart';
  if (!File(routerPath).existsSync()) return;

  final className = _toPascalCase(module);
  var content = File(routerPath).readAsStringSync();
  final before = content.length;

  // Remove the import line
  content = content.replaceAll(
    "import 'package:$_pkg/features/$module/presentation/pages/${module}_page.dart';\n",
    '',
  );

  // Remove top-level GoRoute (exact format we generate)
  content = content.replaceAll(
    "      GoRoute(\n"
    "          path: ${className}Page.route,\n"
    "          name: ${className}Page.route,\n"
    "          builder: (context, state) => const ${className}Page()),\n",
    '',
  );

  // Remove shell GoRoute (exact format we generate)
  content = content.replaceAll(
    "\n          GoRoute(\n"
    "              path: ${className}Page.route,\n"
    "              name: ${className}Page.route,\n"
    "              parentNavigatorKey: _shellKey,\n"
    "              pageBuilder: (context, state) =>\n"
    "                  const NoTransitionPage(child: ${className}Page()),\n"
    "              builder: (context, state) => const ${className}Page())",
    '',
  );

  if (content.length != before) {
    File(routerPath).writeAsStringSync(content);
    print('  ~  lib/core/router/app_router_config.dart  (route removed)');
  }
}

void _removeTests(String module) {
  final testDir = Directory('test/features/$module');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
    print('  Deleted: test/features/$module');
  }
}

// ─── Test file generation ─────────────────────────────────────────────────────

void _generateTestFiles(String module, String className, {String state = 'bloc'}) {
  final testDir = 'test/features/$module';
  Directory('$testDir/domain').createSync(recursive: true);
  Directory('$testDir/presentation').createSync(recursive: true);

  final files = <String, String>{
    '$testDir/domain/${module}_interactor_test.dart':
        _tplInteractorTest(module, className),
  };

  switch (state) {
    case 'cubit':
      files['$testDir/presentation/${module}_cubit_test.dart'] =
          _tplCubitTest(module, className);
    case 'riverpod':
      files['$testDir/presentation/${module}_notifier_test.dart'] =
          _tplRiverpodTest(module, className);
    default: // bloc
      files['$testDir/presentation/${module}_bloc_test.dart'] =
          _tplBlocTest(module, className);
  }

  for (final e in files.entries) {
    File(e.key).writeAsStringSync(e.value);
    print('  +  ${e.key}');
  }
}
