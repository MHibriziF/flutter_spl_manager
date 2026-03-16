import 'package:boilerplate/core/client/api_call.dart';
import 'package:boilerplate/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'local/{{name.snakeCase()}}_local_data_sources.dart';
import 'model/mapper/{{name.snakeCase()}}_mapper.dart';
import 'remote/{{name.snakeCase()}}_remote_data_sources.dart';
import '../domain/model/{{name.snakeCase()}}.dart';
import '../domain/repository/{{name.snakeCase()}}_repository.dart';

@LazySingleton(as: {{name.pascalCase()}}Repository)
class {{name.pascalCase()}}RepositoryImpl implements {{name.pascalCase()}}Repository {
  final {{name.pascalCase()}}RemoteDataSources _remote;
  final {{name.pascalCase()}}LocalDataSources _local;

  const {{name.pascalCase()}}RepositoryImpl(this._remote, this._local);

  @override
  Future<Either<NetworkException, {{name.pascalCase()}}>> getSomething() {
    return apiCall<{{name.pascalCase()}}>(
      func: _remote.getSomething(),
      mapper: (value) => {{name.pascalCase()}}Mapper.mapResponseToDomain(value),
    );
  }
}
