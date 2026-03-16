// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Package name (read from spl.yaml app.package) ───────────────────────────

String? _pkgCache;
String get _pkg {
  if (_pkgCache != null) return _pkgCache!;
  final config = _readSplConfig();
  _pkgCache = config['app']?['package'] as String? ?? 'app';
  return _pkgCache!;
}

// ─── spl.yaml helpers ─────────────────────────────────────────────────────────

Map<String, dynamic> _readSplConfig() {
  const path = 'spl.yaml';
  if (!File(path).existsSync()) _die('spl.yaml not found. Run from project root, or run `spl init` first.');

  final lines = File(path).readAsLinesSync();
  final config = <String, dynamic>{};
  String? section;
  Map<String, String>? currentFeature;

  for (final line in lines) {
    if (line.trim().startsWith('#') || line.trim().isEmpty) continue;

    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      section = line.trim().replaceAll(':', '');
      if (section == 'features') config['features'] = <Map<String, String>>[];
      continue;
    }

    final trimmed = line.trim();

    if (section == 'app' || section == 'storage' || section == 'state_management') {
      final idx = trimmed.indexOf(':');
      if (idx > 0) {
        config.putIfAbsent(section!, () => <String, String>{});
        (config[section] as Map<String, dynamic>)[trimmed.substring(0, idx).trim()] =
            trimmed.substring(idx + 1).trim();
      }
    }

    if (section == 'features') {
      if (trimmed.startsWith('- name:')) {
        currentFeature = {'name': trimmed.replaceFirst('- name:', '').trim()};
        (config['features'] as List).add(currentFeature);
      } else if (currentFeature != null) {
        final idx = trimmed.indexOf(':');
        if (idx > 0) {
          currentFeature[trimmed.substring(0, idx).trim()] =
              trimmed.substring(idx + 1).trim();
        }
      }
    }
  }

  return config;
}

void _addFeatureToConfig(String name,
    {required String storage, required String state}) {
  const path = 'spl.yaml';
  final content = File(path).readAsStringSync();
  File(path).writeAsStringSync(
    '$content\n  - name: $name\n    status: active\n    storage: $storage\n    state: $state\n',
  );
}

void _removeFeatureFromConfig(String name) {
  const path = 'spl.yaml';
  final lines = File(path).readAsLinesSync();
  final result = <String>[];
  bool skip = false;

  for (final line in lines) {
    if (line.trim() == '- name: $name') {
      skip = true;
      if (result.isNotEmpty && result.last.trim().isEmpty) result.removeLast();
      continue;
    }
    if (skip) {
      if (line.trim().startsWith('- name:') || !line.startsWith('  ')) {
        skip = false;
      } else {
        continue;
      }
    }
    result.add(line);
  }
  File(path).writeAsStringSync(result.join('\n'));
}

void _updateFeatureStatusInConfig(String name, String status) {
  const path = 'spl.yaml';
  final lines = File(path).readAsLinesSync();
  final result = <String>[];
  bool inFeature = false;
  bool patched = false;

  for (final line in lines) {
    if (line.trim() == '- name: $name') {
      inFeature = true;
      patched = false;
    } else if (inFeature && line.trim().startsWith('status:') && !patched) {
      result.add(line.replaceFirst(RegExp(r'status:\s*\w+'), 'status: $status'));
      patched = true;
      continue;
    } else if (inFeature && (line.trim().startsWith('- name:') || !line.startsWith('  '))) {
      inFeature = false;
    }
    result.add(line);
  }
  File(path).writeAsStringSync(result.join('\n'));
}

// ─── Storage config helpers ───────────────────────────────────────────────────

void _addStorageToConfig(String provider) {
  final providers = _getActiveProviders();
  if (providers.contains(provider)) return;
  providers.add(provider);
  _setActiveStorageInConfig(providers);
}

void _removeStorageFromConfig(String provider) {
  final providers = _getActiveProviders();
  providers.remove(provider);
  _setActiveStorageInConfig(providers);
}

void _setActiveStorageInConfig(List<String> providers) {
  const path = 'spl.yaml';
  File(path).writeAsStringSync(
    File(path).readAsStringSync().replaceFirst(
      RegExp(r'active:.*'),
      'active: ${providers.join(',')}',
    ),
  );
}

void _updateStorageDefaultInConfig(String provider) {
  const path = 'spl.yaml';
  var content = File(path).readAsStringSync();
  // Handle new format (default:) and old format (local_backend:)
  if (content.contains(RegExp(r'^\s*default:', multiLine: true))) {
    content = content.replaceFirst(RegExp(r'default:.*'), 'default: $provider');
  } else {
    content = content.replaceFirst(RegExp(r'local_backend:.*'), 'default: $provider');
  }
  File(path).writeAsStringSync(content);
}

void _updateStateDefaultInConfig(String solution) {
  const path = 'spl.yaml';
  File(path).writeAsStringSync(
    File(path).readAsStringSync().replaceFirst(
      RegExp(r'default: (bloc|cubit|riverpod)'),
      'default: $solution',
    ),
  );
}

// ─── Mason integration ────────────────────────────────────────────────────────

bool? _masonAvailable;

Future<bool> _checkMason() async {
  if (_masonAvailable != null) return _masonAvailable!;
  final r = await Process.run('mason', ['--version'], runInShell: true);
  _masonAvailable = r.exitCode == 0 && File('.mason/bricks.json').existsSync();
  return _masonAvailable!;
}

// ─── Mason init ───────────────────────────────────────────────────────────────

const _repoUrl = 'https://github.com/MHibriziF/flutter_spl_manager';

const _masonYaml = '''
bricks:
  feature:
    git:
      url: $_repoUrl
      path: bricks/feature
  storage_hive:
    git:
      url: $_repoUrl
      path: bricks/storage_hive
  storage_prefs:
    git:
      url: $_repoUrl
      path: bricks/storage_prefs
  storage_secure:
    git:
      url: $_repoUrl
      path: bricks/storage_secure
  storage_sqflite:
    git:
      url: $_repoUrl
      path: bricks/storage_sqflite
''';

Future<void> _cmdMasonInit() async {
  _printHeader('Setting up Mason bricks');

  // Check mason is installed
  final check = await Process.run('mason', ['--version'], runInShell: true);
  if (check.exitCode != 0) {
    print('  ⚠  Mason not found. Install it first:');
    print('     dart pub global activate mason_cli');
    return;
  }

  const masonYamlPath = 'mason.yaml';
  if (File(masonYamlPath).existsSync()) {
    print('  ~  mason.yaml  (already exists, skipping)');
  } else {
    File(masonYamlPath).writeAsStringSync(_masonYaml);
    print('  +  mason.yaml');
  }

  print('  Running mason get...');
  final result = await Process.run('mason', ['get'], runInShell: true);
  if (result.exitCode != 0) {
    print(result.stderr);
    print('  ⚠  mason get failed. Run `mason get` manually after checking mason.yaml.');
    return;
  }
  print('  ✓  Mason bricks ready. spl add will now use them automatically.');
}

Future<bool> _tryMasonFeature(String module,
    {bool withStorage = false, String state = 'bloc'}) async {
  if (!await _checkMason()) return false;
  print('  Using Mason brick: feature');
  final r = await Process.run(
    'mason',
    ['make', 'feature',
      '--name', module,
      '--with_storage', withStorage.toString(),
      '--state', state,
      '-o', '.', '--no-confirm'],
    runInShell: true,
  );
  if (r.exitCode != 0) {
    print('  Mason failed → falling back to inline templates.');
    return false;
  }
  print(r.stdout);
  return true;
}

Future<bool> _tryMasonStorage(String provider) async {
  if (!await _checkMason()) return false;
  final brick = switch (provider) {
    'flutter_secure_storage' => 'storage_secure',
    'sqflite'                => 'storage_sqflite',
    'hive'                   => 'storage_hive',
    'shared_preferences'     => 'storage_prefs',
    _                        => null,
  };
  if (brick == null) return false;
  print('  Using Mason brick: $brick');
  final r = await Process.run(
    'mason', ['make', brick, '-o', '.', '--no-confirm'],
    runInShell: true,
  );
  if (r.exitCode != 0) {
    print('  Mason failed → falling back to inline templates.');
    return false;
  }
  print(r.stdout);
  return true;
}
