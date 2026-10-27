import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';

/// Uma obra da Open Library (o "work", que agrupa todas as edições).
@freezed
abstract class Book with _$Book {
  const factory Book({
    /// Chave da obra, ex.: `OL1003040W`.
    required String id,
    required String title,
    @Default(<String>[]) List<String> authors,
    int? coverId,
    int? firstPublishYear,
    int? pageCount,
    @Default(<String>[]) List<String> isbns,
    @Default(<String>[]) List<String> subjects,
    String? description,
  }) = _Book;

  const Book._();

  String get authorsLabel => authors.isEmpty ? 'Autor desconhecido' : authors.take(2).join(', ');
}
