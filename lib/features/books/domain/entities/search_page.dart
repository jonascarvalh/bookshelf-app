import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_page.freezed.dart';

/// Uma página de resultados de busca.
@freezed
abstract class SearchPage with _$SearchPage {
  const factory SearchPage({
    required List<Book> books,
    required int page,
    required int totalCount,
  }) = _SearchPage;

  const SearchPage._();

  static const pageSize = 20;

  /// Uma página vazia encerra a rolagem mesmo que `totalCount` diga o
  /// contrário (o índice da Open Library às vezes superestima o total).
  bool get hasMore => books.isNotEmpty && page * pageSize < totalCount;
}
