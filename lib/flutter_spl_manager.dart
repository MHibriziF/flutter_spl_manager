// ignore_for_file: avoid_print
/// Flutter SPL Manager — Software Product Line CLI for Flutter Clean Architecture
///
/// Variability points:
///   Storage (OR)       — one or more backends, each registered with @Named
///   State Mgmt (OR)    — global default, per-feature override allowed
///
/// Usage (after dart pub global activate spl_manager):
///   spl init
///   spl list
///   spl add <name>[,storage=<p>][,state=<s>][,test][,shell] [name2[,...]] ...
///   spl disable <name> [name2 ...]
///   spl enable <name> [name2 ...]
///   spl remove <name> [name2 ...] [--yes|-y]
///   spl storage add|remove|default|list [<provider>]
///   spl state set|list [<solution>]
///   spl fix
library;

import 'dart:io';

part 'src/commands.dart';
part 'src/generators.dart';
part 'src/storage_manager.dart';
part 'src/templates.dart';
part 'src/spl_config.dart';
part 'src/utils.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

Future<void> splMain(List<String> args) async {
  if (args.isEmpty) { _printHelp(); exit(0); }

  switch (args[0]) {
    case 'init':
      await _cmdInit();

    case 'list':
      await _cmdList();

    case 'add':
      final stateIdx             = args.indexOf('--state');
      final globalState          = stateIdx != -1 && stateIdx + 1 < args.length ? args[stateIdx + 1] : null;
      final storageIdx           = args.indexOf('--storage');
      final globalStorageOverride = storageIdx != -1 && storageIdx + 1 < args.length ? args[storageIdx + 1] : null;
      final globalWithStorage    = args.contains('--with-storage') || globalStorageOverride != null;
      final globalWithTest       = args.contains('--with-test');
      final globalShellRoute     = args.contains('--shell-route');
      final specs = <String>[];
      for (var i = 1; i < args.length; i++) {
        if (args[i].startsWith('-')) continue;
        if (stateIdx != -1 && i == stateIdx + 1) continue;
        if (storageIdx != -1 && i == storageIdx + 1) continue;
        specs.add(args[i]);
      }
      if (specs.isEmpty) _die(
        'Usage: spl add <name>[,storage=<p>][,state=<s>][,test][,shell] [name2[,...]] ...\n'
        '  Global flags: --with-storage  --storage <p>  --with-test  --shell-route  --state <s>',
      );
      for (final spec in specs) {
        final f = _parseFeatureSpec(spec,
            globalStorageOverride: globalStorageOverride,
            globalWithStorage:     globalWithStorage,
            globalState:           globalState,
            globalWithTest:        globalWithTest,
            globalShellRoute:      globalShellRoute);
        await _cmdAdd(f.name,
            withStorage:     f.withStorage,
            storageOverride: f.storageOverride,
            withTest:        f.withTest,
            shellRoute:      f.shellRoute,
            stateOverride:   f.stateOverride,
            runDi:           false);
      }
      print('\n  Wiring DI (build_runner)...');
      await _runBuildRunner();
      if (specs.length == 1) {
        final module = specs[0].split(',')[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
        print('\n  ✓ Done! lib/features/$module/');
      } else {
        print('\n  ✓ Done! ${specs.length} features added.');
      }

    case 'disable':
      final names = args.skip(1).where((a) => !a.startsWith('-')).toList();
      if (names.isEmpty) _die('Usage: spl disable <name> [name2 ...]');
      for (final name in names) await _cmdDisable(name, runDi: false);
      print('  Regenerating DI...');
      await _runBuildRunner();
      if (names.length > 1) print('\n  ✓ ${names.length} features disabled.');

    case 'enable':
      final names = args.skip(1).where((a) => !a.startsWith('-')).toList();
      if (names.isEmpty) _die('Usage: spl enable <name> [name2 ...]');
      for (final name in names) await _cmdEnable(name, runDi: false);
      print('  Wiring DI (build_runner)...');
      await _runBuildRunner();
      if (names.length > 1) print('\n  ✓ ${names.length} features enabled.');

    case 'remove':
      final names = args.skip(1).where((a) => !a.startsWith('-')).toList();
      if (names.isEmpty) _die('Usage: spl remove <name> [name2 ...] [--yes|-y]');
      final force = args.contains('--yes') || args.contains('-y');
      var needsDi = false;
      for (final name in names) {
        if (await _cmdRemove(name, force: force, runDi: false)) needsDi = true;
      }
      if (needsDi) {
        print('  Regenerating DI...');
        await _runBuildRunner();
      }
      if (names.length > 1) print('\n  ✓ ${names.length} features removed.');

    case 'storage':
      if (args.length < 2) _die('Usage: spl storage add|remove|default|list [<provider>]');
      switch (args[1]) {
        case 'add':
          if (args.length < 3) _die('Usage: spl storage add <provider>');
          await _cmdStorageAdd(args[2]);
        case 'remove':
          if (args.length < 3) _die('Usage: spl storage remove <provider>');
          await _cmdStorageRemove(args[2]);
        case 'default':
          if (args.length < 3) _die('Usage: spl storage default <provider>');
          _cmdStorageDefault(args[2]);
        case 'list':
          _cmdStorageList();
        default:
          _die('Unknown storage subcommand: ${args[1]}\nValid: add | remove | default | list');
      }

    case 'state':
      if (args.length < 2) _die('Usage: spl state set <solution> | spl state list');
      if (args[1] == 'set') {
        if (args.length < 3) _die('Usage: spl state set <bloc|cubit|riverpod>');
        _cmdStateSet(args[2]);
      } else if (args[1] == 'list') {
        _cmdStateList();
      } else {
        _die('Unknown state subcommand: ${args[1]}');
      }

    case 'fix':
      await _cmdFix();

    default:
      _die('Unknown command: ${args[0]}\nRun `spl` with no arguments to see usage.');
  }
}
