import 'package:freezed_annotation/freezed_annotation.dart';

part 'work_dto.freezed.dart';
part 'work_dto.g.dart';

/// Resposta de `GET /works/{id}.json`; usamos só o que a busca não traz.
@freezed
abstract class WorkDto with _$WorkDto {
  const factory WorkDto({
    required String title,
    @DescriptionConverter() String? description,
    @Default(<int>[]) List<int> covers,
    @Default(<String>[]) List<String> subjects,
  }) = _WorkDto;

  factory WorkDto.fromJson(Map<String, dynamic> json) => _$WorkDtoFromJson(json);
}

/// A sinopse pode vir como texto puro ou como
/// `{"type": "/type/text", "value": "..."}`, e costuma ter Markdown simples
/// (negrito, links e notas de referência), que é removido.
class DescriptionConverter implements JsonConverter<String?, Object?> {
  const DescriptionConverter();

  @override
  String? fromJson(Object? json) {
    final text = switch (json) {
      final String s => s,
      {'value': final String s} => s,
      _ => null,
    };
    final cleaned = text == null ? null : stripMarkdown(text);
    return (cleaned == null || cleaned.isEmpty) ? null : cleaned;
  }

  static String stripMarkdown(String text) => text
      .replaceAll(RegExp(r'^\s*\[\d+\]:\s*\S+.*$', multiLine: true), '') // [1]: https://…
      .replaceAllMapped(RegExp(r'\[([^\]]+)\](\([^)]*\)|\[\d+\])'), (m) => m[1]!) // [texto](url)
      .replaceAll(RegExp(r'\*\*|__'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  Object? toJson(String? object) => object;
}
