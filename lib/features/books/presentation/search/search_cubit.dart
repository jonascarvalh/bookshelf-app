import 'dart:async';
import 'dart:collection';

import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/entities/search_page.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/features/books/presentation/search/search_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Busca com *debounce* e rolagem infinita.
///
/// Cada página é uma assinatura do stream do repositório, que pode emitir o
/// cache e depois a resposta da API. As páginas ficam num mapa ordenado e a
/// lista exibida é a concatenação delas, sem livros repetidos.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository, {this.debounce = const Duration(milliseconds: 450)})
    : super(const SearchState());

  static const minQueryLength = 2;

  final BookRepository _repository;
  final Duration debounce;

  final _pages = SplayTreeMap<int, List<Book>>();
  final _subscriptions = <int, StreamSubscription<Snapshot<SearchPage>>>{};
  Timer? _debounceTimer;

  /// Chamado a cada tecla: só busca quando o usuário para de digitar.
  void queryChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => search(text));
  }

  void search(String text) {
    _debounceTimer?.cancel();
    final query = text.trim();
    if (query == state.query && state.status == SearchStatus.success) return;

    _cancelAll();
    if (query.length < minQueryLength) {
      emit(SearchState(query: query));
      return;
    }
    emit(SearchState(query: query, status: SearchStatus.loading));
    _load(1);
  }

  void loadMore() {
    final canLoad =
        state.status == SearchStatus.success && state.hasMore && !state.isLoadingMore;
    if (!canLoad) return;
    emit(state.copyWith(isLoadingMore: true, pageFailure: null));
    _load((_pages.isEmpty ? 0 : _pages.lastKey()!) + 1);
  }

  /// Tenta de novo a próxima página, se foi ela que falhou, ou a busca toda.
  /// Retorna um Future para servir ao "puxar para atualizar".
  Future<void> retry() async {
    if (state.pageFailure != null) return loadMore();
    final query = state.query;
    _cancelAll();
    emit(SearchState(query: query, status: SearchStatus.loading));
    _load(1);
  }

  void clear() {
    _debounceTimer?.cancel();
    _cancelAll();
    emit(const SearchState());
  }

  void _load(int page) {
    _subscriptions[page] = _repository
        .search(state.query, page: page)
        .listen((snapshot) => _onSnapshot(page, snapshot));
  }

  void _onSnapshot(int page, Snapshot<SearchPage> snapshot) {
    final data = snapshot.data;

    if (data == null) {
      final failure = snapshot.failure;
      if (failure == null) return;
      emit(
        page == 1
            ? state.copyWith(status: SearchStatus.failure, failure: failure)
            : state.copyWith(isLoadingMore: false, pageFailure: failure),
      );
      return;
    }

    _pages[page] = data.books;
    final unique = <String, Book>{};
    for (final book in _pages.values.expand((b) => b)) {
      unique.putIfAbsent(book.id, () => book);
    }
    final isLastPage = page == _pages.lastKey();

    emit(
      state.copyWith(
        status: unique.isEmpty ? SearchStatus.empty : SearchStatus.success,
        books: unique.values.toList(),
        totalCount: data.totalCount,
        hasMore: isLastPage ? data.hasMore : state.hasMore,
        isLoadingMore: false,
        failure: null,
        pageFailure: page > 1 ? snapshot.failure : state.pageFailure,
        isRefreshing: page == 1 ? snapshot.isRefreshing : state.isRefreshing,
        isStale: page == 1 ? snapshot.isStale : state.isStale,
        cachedAt: page == 1 ? snapshot.cachedAt : state.cachedAt,
      ),
    );
  }

  /// Cancela as páginas em andamento sem esperar: um stream parado num
  /// `await` de rede só termina de cancelar quando a requisição volta, e a
  /// nova busca não deve ficar presa a isso.
  void _cancelAll() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _pages.clear();
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _cancelAll();
    return super.close();
  }
}
