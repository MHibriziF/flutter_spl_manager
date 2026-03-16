import 'package:freezed_annotation/freezed_annotation.dart';

part '{{name.snakeCase()}}_response.freezed.dart';
part '{{name.snakeCase()}}_response.g.dart';

@freezed
abstract class {{name.pascalCase()}}Response with _${{name.pascalCase()}}Response {
  const factory {{name.pascalCase()}}Response({
    required int id,
  }) = _{{name.pascalCase()}}Response;

  factory {{name.pascalCase()}}Response.fromJson(Map<String, dynamic> json) =>
      _${{name.pascalCase()}}ResponseFromJson(json);
}
