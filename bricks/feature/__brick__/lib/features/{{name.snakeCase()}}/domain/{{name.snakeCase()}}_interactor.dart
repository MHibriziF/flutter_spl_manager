import 'package:boilerplate/core/client/network_exception.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'repository/{{name.snakeCase()}}_repository.dart';
import 'use_cases/{{name.snakeCase()}}_use_cases.dart';

@LazySingleton(as: {{name.pascalCase()}}UseCases)
class {{name.pascalCase()}}Interactor implements {{name.pascalCase()}}UseCases {
  final {{name.pascalCase()}}Repository _repository;
  const {{name.pascalCase()}}Interactor(this._repository);

  @override
  Future<Either<NetworkException, dynamic>> getSomething() =>
      _repository.getSomething();
}
