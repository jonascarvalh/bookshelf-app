import 'package:book_app/core/error/failures.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_state.freezed.dart';

enum SearchStatus { idle, loading, success, empty, failure }

@freezed
abstract class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String query,
    @Default(SearchStatus.idle) SearchStatus status,
    @Default(<Book>[]) List<Book> books,
    @Default(0) int totalCount,
    @Default(false) bool hasMore,

    /// Buscando a próxima página (rodapé da lista).
    @Default(false) bool isLoadingMore,

    /// Erro da primeira página, quando não havia cache para mostrar.
    Failure? failure,

    /// Erro ao carregar a próxima página; a lista continua visível.
    Failure? pageFailure,

    /// Mostrando o cache enquanto a API responde.
    @Default(false) bool isRefreshing,

    /// Mostrando o cache porque a API falhou ou o aparelho está offline.
    @Default(false) bool isStale,
    DateTime? cachedAt,
  }) = _SearchState;
}
