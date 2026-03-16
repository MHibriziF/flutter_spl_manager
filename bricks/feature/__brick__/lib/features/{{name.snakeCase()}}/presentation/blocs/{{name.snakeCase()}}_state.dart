import 'package:equatable/equatable.dart';

abstract class {{name.pascalCase()}}State extends Equatable {
  const {{name.pascalCase()}}State();

  @override
  List<Object?> get props => [];
}

class {{name.pascalCase()}}InitialState extends {{name.pascalCase()}}State {
  const {{name.pascalCase()}}InitialState();
}

class {{name.pascalCase()}}LoadingState extends {{name.pascalCase()}}State {
  const {{name.pascalCase()}}LoadingState();
}

class {{name.pascalCase()}}SuccessState extends {{name.pascalCase()}}State {
  final dynamic data;
  const {{name.pascalCase()}}SuccessState({required this.data});

  @override
  List<Object?> get props => [data];
}

class {{name.pascalCase()}}ErrorState extends {{name.pascalCase()}}State {
  final String message;
  const {{name.pascalCase()}}ErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}
