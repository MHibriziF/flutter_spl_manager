import '../responses/{{name.snakeCase()}}_response.dart';
import '../../../domain/model/{{name.snakeCase()}}.dart';

class {{name.pascalCase()}}Mapper {
  static {{name.pascalCase()}} mapResponseToDomain({{name.pascalCase()}}Response response) {
    return {{name.pascalCase()}}(id: response.id);
  }
}
