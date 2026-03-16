import 'package:equatable/equatable.dart';

abstract class {{name.pascalCase()}}Event extends Equatable {
  const {{name.pascalCase()}}Event();

  @override
  List<Object?> get props => [];
}

class Get{{name.pascalCase()}}Event extends {{name.pascalCase()}}Event {
  const Get{{name.pascalCase()}}Event();
}
