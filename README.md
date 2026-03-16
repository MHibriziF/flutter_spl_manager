# flutter_spl_manager

A CLI tool for scaffolding and managing features in Flutter Clean Architecture projects.

Handles the full feature lifecycle — create, disable, re-enable, delete — and manages two variability points: **storage backends** (OR: multiple can coexist) and **state management** (OR: global default with per-feature override). All wiring is automatic.

---

## Installation

```bash
dart pub global activate --source git https://github.com/MHibriziF/flutter_spl_manager
```

Make sure the Dart global bin directory is on your `PATH`:

| Platform | Path |
|---|---|
| macOS / Linux | `~/.pub-cache/bin` |
| Windows | `%LOCALAPPDATA%\Pub\Cache\bin` |

Dart will print the path when you activate if it's not already set.

### macOS / Linux

Works out of the box in any bash/zsh terminal after adding the path above to your shell profile.

### Windows — PowerShell or CMD

Works out of the box:

```powershell
spl init
```

### Windows — Git Bash

Dart creates a `spl.bat` on Windows, which Git Bash does not run automatically. Add this alias to your `~/.bashrc`:

```bash
alias spl='spl.bat'
```

Then reload:

```bash
source ~/.bashrc
```

---

## Prerequisites

`flutter_spl_manager` itself has no Dart package dependencies — it only uses `dart:io`.

However, the **Flutter project you run it in** must have these packages for the generated code to compile:

### Always required

```yaml
dependencies:
  # DI
  get_it: ^8.0.0
  injectable: ^2.5.0

  # State management (bloc is default — add riverpod only if you use it)
  flutter_bloc: ^9.0.0
  equatable: ^2.0.7

  # Functional / error handling
  dartz: ^0.10.1

  # Serialization
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Storage (default backend — always needed)
  flutter_secure_storage: ^9.0.0

  # Routing
  go_router: ^14.0.0

dev_dependencies:
  # DI code gen
  injectable_generator: ^2.7.0

  # Serialization code gen
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
```

### Optional — add only when needed

```yaml
dependencies:
  # spl storage add sqflite
  sqflite: ^2.4.0

  # spl storage add hive
  hive_flutter: ^1.1.0

  # spl storage add shared_preferences / shared_preferences_with_cache
  shared_preferences: ^2.3.0

  # spl add <name> --state riverpod
  flutter_riverpod: ^2.6.0

dev_dependencies:
  # spl add <name> --with-test
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.0
  mocktail: ^1.0.4
```

> If you are using the [flutter-clean-architecture](https://github.com/MHibriziF/flutter-clean-architecture) template, all required packages are already included.

---

## Quick Start

Run once in any Flutter project to bootstrap the SPL structure:

```bash
cd my_flutter_project
spl init

# Optional: set up Mason bricks for code generation (requires mason_cli)
spl init --with-mason
```

This creates:
- `spl.yaml` — the single source of truth for all SPL config
- `features_catalog/` — where disabled features are parked
- `lib/core/storage/app_storage.dart` — the `AppStorage` interface
- `lib/core/storage/impl/secure_storage_provider.dart` — default backend
- `lib/core/storage/storage_module.dart` — injectable `@module` (managed, do not edit)
- Patches `analysis_options.yaml` to exclude `features_catalog/` and `bricks/`

Then add your first feature:

```bash
spl add dashboard
spl add orders,storage=sqflite,state=cubit,test
```

---

## Commands

```
spl init [--with-mason]
spl list
spl add <spec> [spec2 ...]
spl disable <name> [name2 ...]
spl enable <name> [name2 ...]
spl remove <name> [name2 ...] [--yes|-y]
spl storage add|remove|default|list [<provider>]
spl state set|list [<solution>]
spl fix
```

---

## `spl add` — Scaffolding Features

Each argument is a **feature spec**: a name with optional comma-separated inline options.

```
<name>[,storage=<provider>][,state=<solution>][,test][,shell]
```

### Examples

```bash
# Single feature, defaults
spl add orders

# Single feature, all options inline — no spaces, no quoting needed
spl add orders,storage=sqflite,state=cubit,test,shell

# Multiple features in one command, each with their own config
spl add orders,storage=sqflite,state=cubit feed,test settings,shell

# Global flags apply to all features that don't override them inline
spl add orders inventory,storage=hive settings --state bloc --with-test
# → orders:    bloc + test   (from global flags)
# → inventory: hive + test   (storage from inline, test from global)
# → settings:  bloc + test   (from global flags)
```

### Inline keys

| Key | Equivalent flag | Description |
|---|---|---|
| `storage=<provider>` | `--storage <provider>` | Specific storage backend |
| `with-storage` / `ws` | `--with-storage` | Use the default backend |
| `state=<solution>` | `--state <solution>` | State management override |
| `test` | `--with-test` | Generate test stubs |
| `shell` | `--shell-route` | Register inside `ShellRoute` (bottom nav) |

### Global flags

| Flag | Description |
|---|---|
| `--with-storage` | Default backend for all features |
| `--storage <provider>` | Specific backend for all features |
| `--state <solution>` | State mgmt for all features |
| `--with-test` | Test stubs for all features |
| `--shell-route` | Shell route for all features |

### Generated structure

```
lib/features/<name>/
  data/
    local/<name>_local_data_sources.dart     (only with storage option)
    model/
      mapper/<name>_mapper.dart
      responses/<name>_response.dart
    remote/<name>_remote_data_sources.dart
    <name>_repository_impl.dart
  domain/
    model/<name>.dart
    repository/<name>_repository.dart
    use_cases/<name>_use_cases.dart
    <name>_interactor.dart
  presentation/
    pages/<name>_page.dart
    blocs/                                   (bloc or cubit)
      <name>_event.dart                      (bloc only)
      <name>_state.dart
      <name>_bloc.dart | <name>_cubit.dart
    providers/                               (riverpod only)
      <name>_state.dart
      <name>_notifier.dart

test/features/<name>/                        (only with --with-test)
  domain/<name>_interactor_test.dart
  presentation/<name>_bloc_test.dart | <name>_cubit_test.dart | <name>_notifier_test.dart
```

The route is injected automatically into `lib/core/router/app_router_config.dart`. DI is re-wired automatically via `build_runner`. When adding multiple features, `build_runner` runs once at the end.

---

## Feature Lifecycle

```
add → active ──disable──→ catalog ──enable──→ active
                               └──remove──→ gone forever
```

| State | Location | Compiled | DI-wired |
|---|---|---|---|
| Active | `lib/features/<name>/` | yes | yes |
| Catalog | `features_catalog/<name>/` | no | no |
| Removed | — | — | — |

`features_catalog/` is excluded from Dart analysis — inactive features never cause compile errors. All code is fully preserved when disabled.

### Disable

```bash
spl disable orders
spl disable orders inventory settings   # multiple at once
```

Moves the feature to the catalog, removes its route, and regenerates DI. If other features import the disabled one, a **warning** is printed listing the affected files — the disable proceeds, fix the imports after.

### Enable

```bash
spl enable orders
spl enable orders inventory             # multiple at once
```

Moves the feature back to `lib/features/`, restores its status in `spl.yaml`, and re-wires DI. Code is restored exactly as it was left.

### Remove (hard delete)

```bash
spl remove orders
spl remove orders --yes                 # skip confirmation prompt
spl remove orders inventory --yes       # multiple at once
```

Permanently deletes the feature, its route, its tests, and its `spl.yaml` entry. Irreversible.

If other features import the target, the CLI **blocks** and lists the dependent files. Use `--yes` to force deletion anyway — you will need to fix the broken imports manually.

---

## Variability Points

### 1. Storage — OR (multiple backends can coexist)

`AppStorage` is the general-purpose caching interface for features. Multiple backends can be active simultaneously — each feature declares which one it uses via `@Named`.

| Provider | Notes |
|---|---|
| `flutter_secure_storage` | Default. Encrypted key-value. No `init()` needed. |
| `sqflite` | SQLite (relational). Best for structured/queryable data. Requires `init()` before `runApp()`. |
| `hive` | Fast binary box store. Requires `hive_flutter` in `pubspec.yaml` and `init()` before `runApp()`. |
| `shared_preferences` | Simple unencrypted key-value. Uses `SharedPreferencesAsync`. Requires `shared_preferences: ^2.3.0` and `init()` before `runApp()`. |
| `shared_preferences_with_cache` | Simple unencrypted key-value with in-memory read cache. Uses `SharedPreferencesWithCache`. Best for frequently read settings. Requires `shared_preferences: ^2.3.0` and `init()` before `runApp()`. |

```bash
spl storage add sqflite          # register a new backend
spl storage remove hive          # unregister (blocked if active features use it)
spl storage default sqflite      # default for --with-storage / ,with-storage
spl storage list                 # show active providers + which features use each
```

When a feature is added with `--storage sqflite` (or `,storage=sqflite`), the CLI auto-registers `sqflite` if not already active, generates its impl file, and wires `@Named('sqflite')` into the feature's local data source:

```dart
@LazySingleton(as: OrdersLocalDataSources)
class OrdersLocalDataSourcesImpl implements OrdersLocalDataSources {
  final AppStorage _storage;
  const OrdersLocalDataSourcesImpl(@Named('sqflite') this._storage);
}
```

> **Note on `SecureDatabase`:** There is a separate `SecureDatabase` abstraction (backed by `FlutterSecureStorage` and the OS keychain) specifically for secrets — auth tokens, refresh tokens, credentials. It is intentionally **not** a variability point. Never store secrets in `AppStorage`.

### 2. State Management — OR (global default + per-feature override)

| Solution | Package | Files generated | Use when |
|---|---|---|---|
| `bloc` | `flutter_bloc` | `_event.dart`, `_state.dart`, `_bloc.dart` | Complex flows with explicit event streams |
| `cubit` | `flutter_bloc` (same package) | `_state.dart`, `_cubit.dart` | Simpler flows, fewer files, methods called directly |
| `riverpod` | `flutter_riverpod` | `_state.dart`, `_notifier.dart` | Riverpod-native UIs; bridges to get_it DI via `di<T>()` |

```bash
spl state set cubit              # change global default
spl state list                   # show all options + current default
```

Override per feature at creation time:

```bash
spl add orders --state riverpod
spl add orders,state=riverpod    # inline equivalent
```

Bloc and cubit coexist with zero config (same `flutter_bloc` package). Riverpod requires:
1. `flutter_riverpod` in `pubspec.yaml`
2. `ProviderScope` wrapping your root widget in `main.dart`

---

## `spl.yaml`

The single source of truth. Managed by the CLI — do not edit manually.

```yaml
app:
  name: My App
  package: my_app          # used in all generated imports

storage:
  active: flutter_secure_storage,sqflite   # comma-separated, OR semantics
  default: flutter_secure_storage

state_management:
  default: bloc

features:
  - name: orders
    status: active
    storage: sqflite
    state: cubit

  - name: onboarding
    status: inactive       # currently in features_catalog/
    storage: none
    state: bloc
```

---

## Mason Bricks (optional)

The CLI uses [Mason](https://pub.dev/packages/mason_cli) for code generation if available, and falls back to its own inline templates automatically. No setup required to use the CLI — Mason is purely an optional enhancement.

### Why use `--with-mason`?

- **Full template control** — the brick source files are copied directly into your project's `bricks/` directory. Edit any template to match your team's conventions: rename files, change imports, add boilerplate, adjust the generated folder structure.
- **Consistent across the team** — once you commit `bricks/`, everyone on the team generates code from the same customised templates.
- **Automatic** — `spl add` and `spl storage add` detect Mason and use the bricks automatically. No extra steps per feature.

Without `--with-mason`, the CLI falls back to its own built-in inline templates — no Mason required.

### Setup

```bash
# Install mason_cli if you haven't already
dart pub global activate mason_cli

# Bootstrap Mason — copies bricks into your project and sets up mason.yaml
spl init --with-mason
```

This will:
1. Copy all SPL brick templates into `bricks/` in your project root
2. Create `mason.yaml` with local `path:` references to those bricks
3. Run `mason get` to register them

After that, `spl add` and `spl storage add` will use your local bricks automatically. To customise a template, edit the files under `bricks/<brick-name>/__brick__/` and commit the changes.

Brick templates use Mustache syntax (`{{name.pascalCase()}}`) — they are excluded from Dart analysis automatically by `spl init`.

---

## DI Regeneration

All generated code uses `@injectable` / `@lazySingleton` annotations. After any `add`, `disable`, `enable`, or `remove`, `build_runner` regenerates `lib/services/di.config.dart` automatically. When operating on multiple features, it runs **once** at the end.

To run it manually:

```bash
spl fix
```

---

## Source Layout

```
lib/
├── flutter_spl_manager.dart    library root — imports, part directives, splMain()
└── src/
    ├── commands.dart            all _cmd* functions including _cmdInit
    ├── generators.dart          file generation, route injection, cross-feature dep check
    ├── storage_manager.dart     backend management, StorageModule rewrite
    ├── templates.dart           all _tpl* code templates
    ├── spl_config.dart          spl.yaml read/write, _pkg getter, Mason integration
    └── utils.dart               spec parser, build_runner, analysis exclusions, help
```

All part files share a single library namespace — private `_` functions are accessible across files with no extra imports.

---

## License

MIT
