import 'package:boilerplate/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';

import '../model/{{name.snakeCase()}}.dart';

abstract class {{name.pascalCase()}}UseCases {
  Future<Either<NetworkException, {{name.pascalCase()}}>> getSomething();
}
