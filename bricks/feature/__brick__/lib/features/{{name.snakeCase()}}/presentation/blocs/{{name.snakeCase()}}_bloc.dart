import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/use_cases/{{name.snakeCase()}}_use_cases.dart';
import '{{name.snakeCase()}}_event.dart';
import '{{name.snakeCase()}}_state.dart';

@Injectable()
class {{name.pascalCase()}}Bloc extends Bloc<{{name.pascalCase()}}Event, {{name.pascalCase()}}State> {
  final {{name.pascalCase()}}UseCases _useCases;

  {{name.pascalCase()}}Bloc(this._useCases) : super(const {{name.pascalCase()}}InitialState()) {
    on<Get{{name.pascalCase()}}Event>(_onGet);
  }

  Future<void> _onGet(
    Get{{name.pascalCase()}}Event event,
    Emitter<{{name.pascalCase()}}State> emit,
  ) async {
    emit(const {{name.pascalCase()}}LoadingState());
    final result = await _useCases.getSomething();
    result.fold(
      (failure) => emit({{name.pascalCase()}}ErrorState(message: failure.message ?? '')),
      (data) => emit({{name.pascalCase()}}SuccessState(data: data)),
    );
  }
}
