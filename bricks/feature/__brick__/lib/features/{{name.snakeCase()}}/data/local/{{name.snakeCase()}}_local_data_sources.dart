{{#with_storage}}import 'package:boilerplate/core/storage/app_storage.dart';
{{/with_storage}}import 'package:injectable/injectable.dart';

abstract class {{name.pascalCase()}}LocalDataSources {
{{#with_storage}}  Future<void> cache(String key, dynamic value);
  Future<T?> getCached<T>(String key);
  Future<void> clearCache();
{{/with_storage}}}

@LazySingleton(as: {{name.pascalCase()}}LocalDataSources)
class {{name.pascalCase()}}LocalDataSourcesImpl implements {{name.pascalCase()}}LocalDataSources {
{{#with_storage}}  final AppStorage _storage;
  const {{name.pascalCase()}}LocalDataSourcesImpl(this._storage);

  @override
  Future<void> cache(String key, dynamic value) => _storage.put(key, value);

  @override
  Future<T?> getCached<T>(String key) => _storage.get<T>(key);

  @override
  Future<void> clearCache() => _storage.clear();
{{/with_storage}}{{^with_storage}}  const {{name.pascalCase()}}LocalDataSourcesImpl();
{{/with_storage}}}
