// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Per-feature spec parser ──────────────────────────────────────────────────
//
// Parses a feature spec string of the form:
//   name[,storage=<provider>][,with-storage][,state=<solution>][,test][,shell]
//
// Per-feature keys override the global flags passed as defaults.
// Examples:
//   "orders"                           → no options
//   "orders,storage=sqflite,state=cubit" → sqflite + cubit override
//   "settings,test,shell"              → with tests, shell route
//   "feed,with-storage"                → use global default backend

({
  String name,
  String? storageOverride,
  bool withStorage,
  String? stateOverride,
  bool withTest,
  bool shellRoute,
}) _parseFeatureSpec(
  String spec, {
  String? globalStorageOverride,
  bool globalWithStorage = false,
  String? globalState,
  bool globalWithTest = false,
  bool globalShellRoute = false,
}) {
  final parts = spec.split(',');
  final name = parts[0];

  String? storageOverride = globalStorageOverride;
  bool withStorage        = globalWithStorage;
  String? stateOverride   = globalState;
  bool withTest           = globalWithTest;
  bool shellRoute         = globalShellRoute;

  for (final part in parts.skip(1)) {
    if (part.startsWith('storage=')) {
      storageOverride = part.substring(8);
      withStorage     = true;
    } else if (part == 'with-storage' || part == 'ws') {
      withStorage = true;
    } else if (part.startsWith('state=')) {
      stateOverride = part.substring(6);
    } else if (part == 'test') {
      withTest = true;
    } else if (part == 'shell') {
      shellRoute = true;
    }
  }

  return (
    name:            name,
    storageOverride: storageOverride,
    withStorage:     withStorage,
    stateOverride:   stateOverride,
    withTest:        withTest,
    shellRoute:      shellRoute,
  );
}

// ─── Validation + Notes ───────────────────────────────────────────────────────

void _validateStateChoice(String state) {
  const valid = ['bloc', 'cubit', 'riverpod'];
  if (!valid.contains(state)) {
    _die('Unknown state: "$state"\nValid: ${valid.join(' | ')}');
  }
}

void _printStateNotes(String state) {
  if (state == 'riverpod') {
    print('');
    print('  ⚠  Riverpod requires: flutter_riverpod in pubspec.yaml');
    print('  ⚠  Add ProviderScope at the root of your widget tree in main()');
  }
}

void _printStorageNotes(String provider) {
  switch (provider) {
    case 'hive':
      print('\n  ⚠  Add: hive_flutter: ^1.1.0 to pubspec.yaml');
      print('  ⚠  Call di<AppStorage>().init() in main() before runApp()');
    case 'shared_preferences':
      print('\n  ⚠  Add: shared_preferences: ^2.3.0 to pubspec.yaml');
      print('  ⚠  Call di<AppStorage>().init() in main() before runApp()');
    case 'sqflite':
      print('\n  ⚠  Call di<AppStorage>().init() in main() before runApp()');
    default:
      break;
  }
}

// ─── analysis_options.yaml exclusions ────────────────────────────────────────

void _ensureAnalysisExclusions() {
  const path = 'analysis_options.yaml';
  const exclusions = ['features_catalog/**', 'bricks/**'];

  if (!File(path).existsSync()) {
    File(path).writeAsStringSync(
      'analyzer:\n  exclude:\n    - features_catalog/**\n    - bricks/**\n',
    );
    print('  +  $path  (created with exclusions)');
    return;
  }

  var content = File(path).readAsStringSync();
  var modified = false;

  for (final exc in exclusions) {
    if (content.contains(exc)) continue;

    if (content.contains('exclude:')) {
      // Append to existing exclude list
      content = content.replaceFirst(
        RegExp(r'(exclude:\s*\n)'),
        '\$1    - $exc\n',
      );
    } else if (content.contains('analyzer:')) {
      content = content.replaceFirst(
        RegExp(r'(analyzer:\s*\n)'),
        '\$1  exclude:\n    - $exc\n',
      );
    } else {
      content += '\nanalyzer:\n  exclude:\n    - $exc\n';
    }
    modified = true;
  }

  if (modified) {
    File(path).writeAsStringSync(content);
    print('  ~  $path  (exclusions added)');
  } else {
    print('  ~  $path  (exclusions already present)');
  }
}

// ─── build_runner ─────────────────────────────────────────────────────────────

Future<void> _runBuildRunner() async {
  final result = await Process.run(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    print('\n${result.stderr}');
    _die('build_runner failed (exit ${result.exitCode})');
  }
  print('  build_runner: OK');
}

// ─── Utilities ────────────────────────────────────────────────────────────────

String _toPascalCase(String s) => s
    .split(RegExp(r'[_\s-]+'))
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join();

void _printHeader(String t) {
  print('');
  print('  ══ $t ══');
  print('');
}

void _printHelp() {
  print('''
SPL Manager — Software Product Line CLI for Flutter Clean Architecture

Setup (run once per project):
  spl init                              Bootstrap spl.yaml, AppStorage, catalog dir
  spl init --with-mason                 Also set up Mason bricks (requires mason_cli)

Variability:
  Storage [OR]      multiple backends can coexist; each feature picks one
  State Mgmt [OR]   global default + per-feature override

Commands:
  list
  add <spec> [spec2 ...]
    Scaffold one or more features. Each spec is:
      <name>[,storage=<p>][,state=<s>][,test][,shell]

    Inline examples:
      add orders,storage=sqflite,state=cubit
      add feed,test inventory,shell settings
      add orders,storage=sqflite feed,with-storage settings

    Global flags (apply to all features unless overridden inline):
      --with-storage              Use default storage backend
      --storage <provider>        Use a specific backend for all
      --with-test                 Generate tests for all
      --shell-route               Shell route for all
      --state bloc|cubit|riverpod State mgmt for all

    Available providers: flutter_secure_storage | sqflite | hive | shared_preferences

  disable <name> [name2 ...]             Move to catalog — code kept, DI removed
  enable <name> [name2 ...]              Restore from catalog — DI re-wired
  remove <name> [name2 ...] [--yes|-y]   Hard delete
                                         --yes required when cross-feature deps found
  storage add <provider>                 Register a new storage backend
  storage remove <provider>              Unregister a backend
  storage default <provider>             Set default for --with-storage / ,with-storage
  storage list
  state set <bloc|cubit|riverpod>        Change default state mgmt
  state list
  fix                                    Re-run build_runner
''');
}

Never _die(String msg) {
  stderr.writeln('\n  ✗  $msg\n');
  exit(1);
}
