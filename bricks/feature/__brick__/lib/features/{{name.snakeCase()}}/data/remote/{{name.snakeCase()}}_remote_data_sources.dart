import 'package:boilerplate/core/client/network_service.dart';
import 'package:injectable/injectable.dart';

import '../model/responses/{{name.snakeCase()}}_response.dart';

abstract class {{name.pascalCase()}}RemoteDataSources {
  Future<{{name.pascalCase()}}Response> getSomething();
}

@LazySingleton(as: {{name.pascalCase()}}RemoteDataSources)
class {{name.pascalCase()}}RemoteDataSourceImpl implements {{name.pascalCase()}}RemoteDataSources {
  final NetworkService _networkService;
  const {{name.pascalCase()}}RemoteDataSourceImpl(this._networkService);

  @override
  Future<{{name.pascalCase()}}Response> getSomething() async {
    // TODO: implement using _networkService
    throw UnimplementedError();
  }
}
