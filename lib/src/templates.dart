// ignore_for_file: avoid_print
part of '../flutter_spl_manager.dart';

// ─── Code templates — State Management ───────────────────────────────────────

String _tplState(String className) => '''
import 'package:equatable/equatable.dart';

abstract class ${className}State extends Equatable {
  const ${className}State();
  @override
  List<Object?> get props => [];
}

class ${className}InitialState extends ${className}State {
  const ${className}InitialState();
}

class ${className}LoadingState extends ${className}State {
  const ${className}LoadingState();
}

class ${className}SuccessState extends ${className}State {
  final dynamic data;
  const ${className}SuccessState({required this.data});
  @override
  List<Object?> get props => [data];
}

class ${className}ErrorState extends ${className}State {
  final String message;
  const ${className}ErrorState({required this.message});
  @override
  List<Object?> get props => [message];
}
''';

// ── BLoC ──────────────────────────────────────────────────────────────────────

String _tplEvent(String className) => '''
import 'package:equatable/equatable.dart';

abstract class ${className}Event extends Equatable {
  const ${className}Event();
  @override
  List<Object?> get props => [];
}

class Get${className}Event extends ${className}Event {
  const Get${className}Event();
}
''';

String _tplBloc(String module, String className) => '''
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/use_cases/${module}_use_cases.dart';
import '${module}_event.dart';
import '${module}_state.dart';

@Injectable()
class ${className}Bloc extends Bloc<${className}Event, ${className}State> {
  final ${className}UseCases _useCases;

  ${className}Bloc(this._useCases) : super(const ${className}InitialState()) {
    on<Get${className}Event>(_onGet);
  }

  Future<void> _onGet(
    Get${className}Event event,
    Emitter<${className}State> emit,
  ) async {
    emit(const ${className}LoadingState());
    final result = await _useCases.getSomething();
    result.fold(
      (failure) => emit(${className}ErrorState(message: failure.message ?? '')),
      (data)    => emit(${className}SuccessState(data: data)),
    );
  }
}
''';

// ── Cubit ─────────────────────────────────────────────────────────────────────

String _tplCubit(String module, String className) => '''
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/use_cases/${module}_use_cases.dart';
import '${module}_state.dart';

// Cubit: no event classes needed. Call methods directly from UI.
// Uses flutter_bloc — same package as Bloc, no extra dependency.
@Injectable()
class ${className}Cubit extends Cubit<${className}State> {
  final ${className}UseCases _useCases;

  ${className}Cubit(this._useCases) : super(const ${className}InitialState());

  Future<void> getSomething() async {
    emit(const ${className}LoadingState());
    final result = await _useCases.getSomething();
    result.fold(
      (failure) => emit(${className}ErrorState(message: failure.message ?? '')),
      (data)    => emit(${className}SuccessState(data: data)),
    );
  }
}
''';

// ── Riverpod ──────────────────────────────────────────────────────────────────

String _tplRiverpodNotifier(String module, String className) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/di.dart';
import '../../domain/use_cases/${module}_use_cases.dart';
import '${module}_state.dart';

// Bridges injectable get_it DI → Riverpod.
// The domain/data layers stay injectable; only the presentation uses Riverpod.
final ${module}UseCasesProvider = Provider<${className}UseCases>(
  (ref) => di<${className}UseCases>(),
);

final ${module}NotifierProvider =
    AsyncNotifierProvider.autoDispose<${className}Notifier, ${className}State>(
  ${className}Notifier.new,
);

class ${className}Notifier
    extends AutoDisposeAsyncNotifier<${className}State> {
  late ${className}UseCases _useCases;

  @override
  Future<${className}State> build() async {
    _useCases = ref.read(${module}UseCasesProvider);
    return const ${className}InitialState();
  }

  Future<void> getSomething() async {
    state = const AsyncValue.loading();
    final result = await _useCases.getSomething();
    result.fold(
      (failure) => state =
          AsyncError(failure.message ?? 'Error', StackTrace.current),
      (data) => state = AsyncData(${className}SuccessState(data: data)),
    );
  }
}
''';

// ─── Storage provider templates ───────────────────────────────────────────────

String _tplSecureStorageProvider() => r'''
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app_storage.dart';

/// [AppStorage] backed by FlutterSecureStorage.
/// Managed by spl_manager. To switch: spl storage set <provider>
class SecureStorageProvider implements AppStorage {
  final FlutterSecureStorage _storage;
  const SecureStorageProvider(this._storage);

  @override Future<void> init() async {}

  @override
  Future<void> put(String key, dynamic value) async =>
      _storage.write(key: key, value: value.toString());

  @override
  Future<T?> get<T>(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    if (T == int) return int.tryParse(value) as T?;
    if (T == double) return double.tryParse(value) as T?;
    if (T == bool) return (value == 'true') as T?;
    return value as T?;
  }

  @override Future<void> delete(String key) async => _storage.delete(key: key);
  @override Future<void> clear() async => _storage.deleteAll();
  @override Future<bool> contains(String key) async =>
      _storage.containsKey(key: key);
}
''';

String _tplSqfliteProvider() => r'''
import 'package:sqflite/sqflite.dart';
import '../app_storage.dart';

/// [AppStorage] backed by sqflite.
/// Call di<AppStorage>().init() in main() before runApp().
class SqfliteStorageProvider implements AppStorage {
  Database? _db;
  static const _table = 'kv_store';

  @override
  Future<void> init() async {
    final path = await getDatabasesPath();
    _db = await openDatabase(
      '$path/app_storage.db',
      version: 1,
      onCreate: (db, _) async => db.execute(
        'CREATE TABLE $_table (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    );
  }

  @override
  Future<void> put(String key, dynamic value) async =>
      _db!.insert(_table, {'key': key, 'value': value.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace);

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

  @override Future<void> delete(String key) async =>
      _db!.delete(_table, where: 'key = ?', whereArgs: [key]);
  @override Future<void> clear() async => _db!.delete(_table);
  @override Future<bool> contains(String key) async {
    final rows = await _db!.query(_table, where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty;
  }
}
''';

String _tplHiveProvider() => r'''
import 'package:hive_flutter/hive_flutter.dart';
import '../app_storage.dart';

/// [AppStorage] backed by Hive.
/// Requires: hive_flutter: ^1.1.0 in pubspec.yaml
/// Call di<AppStorage>().init() in main() before runApp().
class HiveStorageProvider implements AppStorage {
  late Box _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('app_storage');
  }

  @override Future<void> put(String key, dynamic value) async => _box.put(key, value);
  @override Future<T?> get<T>(String key) async => _box.get(key) as T?;
  @override Future<void> delete(String key) async => _box.delete(key);
  @override Future<void> clear() async => _box.clear();
  @override Future<bool> contains(String key) async => _box.containsKey(key);
}
''';

String _tplSharedPrefsProvider() => r'''
import 'package:shared_preferences/shared_preferences.dart';
import '../app_storage.dart';

/// [AppStorage] backed by SharedPreferences.
/// Requires: shared_preferences: ^2.3.0 in pubspec.yaml
/// Call di<AppStorage>().init() in main() before runApp().
class SharedPrefsStorageProvider implements AppStorage {
  late SharedPreferences _prefs;

  @override
  Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  @override
  Future<void> put(String key, dynamic value) async {
    if (value is int)         await _prefs.setInt(key, value);
    else if (value is double)  await _prefs.setDouble(key, value);
    else if (value is bool)    await _prefs.setBool(key, value);
    else                       await _prefs.setString(key, value.toString());
  }

  @override Future<T?> get<T>(String key) async => _prefs.get(key) as T?;
  @override Future<void> delete(String key) async => _prefs.remove(key);
  @override Future<void> clear() async => _prefs.clear();
  @override Future<bool> contains(String key) async => _prefs.containsKey(key);
}
''';

// ─── Data/Domain templates (shared across all state mgmt choices) ─────────────

/// [storageProvider] — the named backend to inject (e.g. 'sqflite').
/// Null means no local storage for this feature.
String _tplLocalDataSources(String module, String className,
    {String? storageProvider}) {
  if (storageProvider == null) {
    return '''import 'package:injectable/injectable.dart';

abstract class ${className}LocalDataSources {}

@LazySingleton(as: ${className}LocalDataSources)
class ${className}LocalDataSourcesImpl implements ${className}LocalDataSources {
  const ${className}LocalDataSourcesImpl();
}
''';
  }
  return '''import 'package:$_pkg/core/storage/app_storage.dart';
import 'package:injectable/injectable.dart';

abstract class ${className}LocalDataSources {
  Future<void> cache(String key, dynamic value);
  Future<T?> getCached<T>(String key);
  Future<void> clearCache();
}

@LazySingleton(as: ${className}LocalDataSources)
class ${className}LocalDataSourcesImpl implements ${className}LocalDataSources {
  final AppStorage _storage;
  const ${className}LocalDataSourcesImpl(@Named('$storageProvider') this._storage);

  @override
  Future<void> cache(String key, dynamic value) => _storage.put(key, value);

  @override
  Future<T?> getCached<T>(String key) => _storage.get<T>(key);

  @override
  Future<void> clearCache() => _storage.clear();
}
''';
}

String _tplMapper(String module, String className) => '''
import '../responses/${module}_response.dart';
import '../../../domain/model/$module.dart';

class ${className}Mapper {
  static $className mapResponseToDomain(${className}Response response) {
    return $className(id: response.id);
  }
}
''';

String _tplResponse(String module, String className) => '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${module}_response.freezed.dart';
part '${module}_response.g.dart';

@freezed
abstract class ${className}Response with _\$${className}Response {
  const factory ${className}Response({
    required int id,
  }) = _${className}Response;

  factory ${className}Response.fromJson(Map<String, dynamic> json) =>
      _\$${className}ResponseFromJson(json);
}
''';

String _tplRemoteDataSources(String module, String className) => '''
import 'package:$_pkg/core/client/network_service.dart';
import 'package:injectable/injectable.dart';

import '../model/responses/${module}_response.dart';

abstract class ${className}RemoteDataSources {
  Future<${className}Response> getSomething();
}

@LazySingleton(as: ${className}RemoteDataSources)
class ${className}RemoteDataSourceImpl implements ${className}RemoteDataSources {
  final NetworkService _networkService;
  const ${className}RemoteDataSourceImpl(this._networkService);

  @override
  Future<${className}Response> getSomething() async {
    // TODO: implement via _networkService
    throw UnimplementedError();
  }
}
''';

String _tplRepositoryImpl(String module, String className) => '''
import 'package:$_pkg/core/client/api_call.dart';
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'local/${module}_local_data_sources.dart';
import 'model/mapper/${module}_mapper.dart';
import 'remote/${module}_remote_data_sources.dart';
import '../domain/model/$module.dart';
import '../domain/repository/${module}_repository.dart';

@LazySingleton(as: ${className}Repository)
class ${className}RepositoryImpl implements ${className}Repository {
  final ${className}RemoteDataSources _remote;
  final ${className}LocalDataSources _local;

  const ${className}RepositoryImpl(this._remote, this._local);

  @override
  Future<Either<NetworkException, $className>> getSomething() {
    return apiCall<$className>(
      func: _remote.getSomething(),
      mapper: (value) => ${className}Mapper.mapResponseToDomain(value),
    );
  }
}
''';

String _tplModel(String className) => '''
class $className {
  final int id;
  const $className({required this.id});
}
''';

String _tplRepository(String module, String className) => '''
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';

import '../model/$module.dart';

abstract class ${className}Repository {
  Future<Either<NetworkException, $className>> getSomething();
}
''';

String _tplUseCases(String module, String className) => '''
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';

import '../model/$module.dart';

abstract class ${className}UseCases {
  Future<Either<NetworkException, $className>> getSomething();
}
''';

String _tplInteractor(String module, String className) => '''
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'model/$module.dart';
import 'repository/${module}_repository.dart';
import 'use_cases/${module}_use_cases.dart';

@LazySingleton(as: ${className}UseCases)
class ${className}Interactor implements ${className}UseCases {
  final ${className}Repository _repository;
  const ${className}Interactor(this._repository);

  @override
  Future<Either<NetworkException, $className>> getSomething() =>
      _repository.getSomething();
}
''';

String _tplPage(String module, String className) => '''
import 'package:flutter/material.dart';

class ${className}Page extends StatelessWidget {
  static const route = '/$module';
  const ${className}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$className')),
      body: const Center(child: Text('$className — replace me')),
    );
  }
}
''';

// ─── Test templates ───────────────────────────────────────────────────────────

String _tplInteractorTest(String module, String className) => '''
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:$_pkg/features/$module/domain/${module}_interactor.dart';
import 'package:$_pkg/features/$module/domain/model/$module.dart';
import 'package:$_pkg/features/$module/domain/repository/${module}_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Mock${className}Repository extends Mock implements ${className}Repository {}

void main() {
  late ${className}Interactor interactor;
  late Mock${className}Repository mockRepository;

  setUp(() {
    mockRepository = Mock${className}Repository();
    interactor = ${className}Interactor(mockRepository);
  });

  group('${className}Interactor', () {
    test('getSomething returns data on success', () async {
      when(() => mockRepository.getSomething())
          .thenAnswer((_) async => Right($className(id: 1)));

      final result = await interactor.getSomething();

      expect(result.isRight(), true);
      verify(() => mockRepository.getSomething()).called(1);
    });

    test('getSomething returns failure on error', () async {
      when(() => mockRepository.getSomething())
          .thenAnswer((_) async => Left(NetworkException(message: 'error')));

      final result = await interactor.getSomething();

      expect(result.isLeft(), true);
    });
  });
}
''';

String _tplBlocTest(String module, String className) => '''
import 'package:bloc_test/bloc_test.dart';
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:$_pkg/features/$module/domain/model/$module.dart';
import 'package:$_pkg/features/$module/domain/use_cases/${module}_use_cases.dart';
import 'package:$_pkg/features/$module/presentation/blocs/${module}_bloc.dart';
import 'package:$_pkg/features/$module/presentation/blocs/${module}_event.dart';
import 'package:$_pkg/features/$module/presentation/blocs/${module}_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Mock${className}UseCases extends Mock implements ${className}UseCases {}

void main() {
  late Mock${className}UseCases mockUseCases;

  setUp(() {
    mockUseCases = Mock${className}UseCases();
  });

  group('${className}Bloc', () {
    blocTest<${className}Bloc, ${className}State>(
      'emits [Loading, Success] when getSomething succeeds',
      build: () => ${className}Bloc(mockUseCases),
      setUp: () {
        when(() => mockUseCases.getSomething())
            .thenAnswer((_) async => Right($className(id: 1)));
      },
      act: (bloc) => bloc.add(const Get${className}Event()),
      expect: () => [
        const ${className}LoadingState(),
        isA<${className}SuccessState>(),
      ],
    );

    blocTest<${className}Bloc, ${className}State>(
      'emits [Loading, Error] when getSomething fails',
      build: () => ${className}Bloc(mockUseCases),
      setUp: () {
        when(() => mockUseCases.getSomething())
            .thenAnswer((_) async => Left(NetworkException(message: 'error')));
      },
      act: (bloc) => bloc.add(const Get${className}Event()),
      expect: () => [
        const ${className}LoadingState(),
        isA<${className}ErrorState>(),
      ],
    );
  });
}
''';

String _tplCubitTest(String module, String className) => '''
import 'package:bloc_test/bloc_test.dart';
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:$_pkg/features/$module/domain/model/$module.dart';
import 'package:$_pkg/features/$module/domain/use_cases/${module}_use_cases.dart';
import 'package:$_pkg/features/$module/presentation/blocs/${module}_cubit.dart';
import 'package:$_pkg/features/$module/presentation/blocs/${module}_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Mock${className}UseCases extends Mock implements ${className}UseCases {}

void main() {
  late Mock${className}UseCases mockUseCases;

  setUp(() {
    mockUseCases = Mock${className}UseCases();
  });

  group('${className}Cubit', () {
    blocTest<${className}Cubit, ${className}State>(
      'emits [Loading, Success] when getSomething succeeds',
      build: () => ${className}Cubit(mockUseCases),
      setUp: () {
        when(() => mockUseCases.getSomething())
            .thenAnswer((_) async => Right($className(id: 1)));
      },
      act: (cubit) => cubit.getSomething(),
      expect: () => [
        const ${className}LoadingState(),
        isA<${className}SuccessState>(),
      ],
    );

    blocTest<${className}Cubit, ${className}State>(
      'emits [Loading, Error] when getSomething fails',
      build: () => ${className}Cubit(mockUseCases),
      setUp: () {
        when(() => mockUseCases.getSomething())
            .thenAnswer((_) async => Left(NetworkException(message: 'error')));
      },
      act: (cubit) => cubit.getSomething(),
      expect: () => [
        const ${className}LoadingState(),
        isA<${className}ErrorState>(),
      ],
    );
  });
}
''';

String _tplRiverpodTest(String module, String className) => '''
import 'package:$_pkg/core/client/network_exception.dart';
import 'package:$_pkg/features/$module/domain/model/$module.dart';
import 'package:$_pkg/features/$module/domain/use_cases/${module}_use_cases.dart';
import 'package:$_pkg/features/$module/presentation/providers/${module}_notifier.dart';
import 'package:$_pkg/features/$module/presentation/providers/${module}_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Mock${className}UseCases extends Mock implements ${className}UseCases {}

void main() {
  late Mock${className}UseCases mockUseCases;

  setUp(() {
    mockUseCases = Mock${className}UseCases();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          ${module}UseCasesProvider.overrideWithValue(mockUseCases),
        ],
      );

  group('${className}Notifier', () {
    test('initial state is ${className}InitialState', () async {
      when(() => mockUseCases.getSomething())
          .thenAnswer((_) async => Right($className(id: 1)));

      final container = makeContainer();
      addTearDown(container.dispose);

      final state = await container.read(${module}NotifierProvider.future);
      expect(state, isA<${className}InitialState>());
    });
  });
}
''';

// ─── Init templates ───────────────────────────────────────────────────────────

String _tplAppStorage() => '''
/// General-purpose local storage interface for feature caching.
///
/// This is an SPL variability point — multiple backends can be active
/// simultaneously, each registered with @Named('provider_name').
///
/// Do NOT use this for secrets (auth tokens, credentials). Use SecureDatabase
/// (backed by FlutterSecureStorage / OS keychain) for those instead.
abstract class AppStorage {
  /// Initialise the backend. Call in main() before runApp() for all backends
  /// except flutter_secure_storage (which needs no init).
  Future<void> init();

  Future<void> put(String key, dynamic value);
  Future<T?> get<T>(String key);
  Future<void> delete(String key);
  Future<void> clear();
  Future<bool> contains(String key);
}
''';

String _tplSplYaml(String projectName, String packageName) => '''
# SPL Configuration — managed by the spl CLI. Do not edit manually.
# Commands: spl add|disable|enable|remove|storage|state|list|fix
app:
  name: $projectName
  package: $packageName

storage:
  # Active storage backends (OR — multiple can coexist, comma-separated).
  # Each active provider is registered with @Named('provider_name') in StorageModule.
  active: flutter_secure_storage
  default: flutter_secure_storage

state_management:
  # Default state mgmt for new features. Override per-feature with --state or ,state=.
  # Options: bloc | cubit | riverpod
  default: bloc

features:
''';
