import 'dart:async';

import 'package:book_app/core/error/exceptions.dart';
import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/network/connectivity_service.dart';
import 'package:book_app/core/result/result.dart';
import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/data/datasources/book_local_data_source.dart';
import 'package:book_app/features/books/data/datasources/book_remote_data_source.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/entities/search_page.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:flutter/foundation.dart';

/// Repositório *offline-first*: o banco local é a fonte que a tela lê
/// primeiro, e a API só atualiza esse banco.
///
/// Estratégia (stale-while-revalidate):
/// - existe cache recente → mostra e não chama a API;
/// - existe cache antigo → mostra na hora e revalida em seguida;
/// - sem internet ou API com erro → mantém o cache e informa a falha;
/// - sem cache e sem API → falha, para a tela mostrar o erro.
class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({
    required this._remote,
    required this._local,
    required this._connectivity,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Uma busca feita há menos tempo que isso não vai à rede de novo.
  static const searchFreshFor = Duration(minutes: 30);

  /// Detalhes (sinopse) mudam pouco: revalida uma vez por semana.
  static const bookFreshFor = Duration(days: 7);

  /// Buscas mais antigas que isso são apagadas na abertura do app.
  static const keepCacheFor = Duration(days: 30);

  final BookRemoteDataSource _remote;
  final BookLocalDataSource _local;
  final ConnectivityService _connectivity;
  final DateTime Function() _clock;

  @visibleForTesting
  static String normalizeQuery(String query) =>
      query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Stream<Snapshot<SearchPage>> search(String query, {int page = 1}) async* {
    final key = normalizeQuery(query);
    final cached = await _readCache(() => _local.getSearch(key, page));
    final cachedPage = cached == null
        ? null
        : SearchPage(books: cached.books, page: page, totalCount: cached.totalCount);
    final isFresh = cached != null && _clock().difference(cached.cachedAt) < searchFreshFor;

    if (cachedPage != null) {
      yield Snapshot(
        data: cachedPage,
        origin: DataOrigin.cache,
        isRefreshing: !isFresh,
        cachedAt: cached!.cachedAt,
      );
      if (isFresh) return;
    }

    Snapshot<SearchPage> fromCache(Failure failure) => Snapshot(
      data: cachedPage,
      origin: DataOrigin.cache,
      failure: failure,
      cachedAt: cached?.cachedAt,
    );

    if (!await _connectivity.isOnline) {
      yield fromCache(const NoConnectionFailure());
      return;
    }

    try {
      final response = await _remote.search(key, page: page);
      final books = [for (final doc in response.docs) doc.toEntity()];
      await _writeCache(() => _local.saveSearch(key, page, books, response.numFound));
      yield Snapshot(
        data: SearchPage(books: books, page: page, totalCount: response.numFound),
        origin: DataOrigin.remote,
      );
    } on ApiException catch (e) {
      yield fromCache(e.toFailure());
    }
  }

  @override
  Stream<Snapshot<Book>> watchBook(String id) async* {
    final cached = await _readCache(() => _local.getBook(id));
    final cachedBook = cached?.$1;
    final needsRefresh =
        cached == null ||
        cachedBook!.description == null ||
        _clock().difference(cached.$2) > bookFreshFor;

    if (cachedBook != null) {
      yield Snapshot(
        data: cachedBook,
        origin: DataOrigin.cache,
        isRefreshing: needsRefresh,
        cachedAt: cached!.$2,
      );
    }
    if (!needsRefresh) return;

    if (!await _connectivity.isOnline) {
      yield Snapshot(
        data: cachedBook,
        origin: DataOrigin.cache,
        failure: const NoConnectionFailure(),
      );
      return;
    }

    try {
      final work = await _remote.getWork(id);
      final base = cachedBook ?? Book(id: id, title: work.title);
      final merged = base.copyWith(
        description: work.description ?? base.description,
        coverId: base.coverId ?? work.covers.where((c) => c > 0).firstOrNull,
        subjects: base.subjects.isEmpty ? work.subjects.take(8).toList() : base.subjects,
      );
      await _writeCache(() => _local.upsertBooks([merged]));
      yield Snapshot(data: merged, origin: DataOrigin.remote);
    } on ApiException catch (e) {
      yield Snapshot(data: cachedBook, origin: DataOrigin.cache, failure: e.toFailure());
    }
  }

  @override
  Future<Result<Book>> findByIsbn(String isbn) async {
    final normalized = isbn.replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();

    final local = await _readCache(() => _local.findByIsbn(normalized));
    if (local != null) return Ok(local);

    if (!await _connectivity.isOnline) return const Err(NoConnectionFailure());

    try {
      final doc = await _remote.findByIsbn(normalized);
      if (doc == null) {
        return Err(NotFoundFailure('Nenhum livro com o ISBN $normalized na Open Library.'));
      }
      var book = doc.toEntity();
      if (!book.isbns.contains(normalized)) {
        book = book.copyWith(isbns: [normalized, ...book.isbns]);
      }
      await _writeCache(() => _local.upsertBooks([book]));
      return Ok(book);
    } on ApiException catch (e) {
      return Err(e.toFailure());
    }
  }

  @override
  Future<void> save(Book book) => _writeCache(() => _local.upsertBooks([book]));

  @override
  Future<void> evictStaleCache() =>
      _writeCache(() => _local.deleteSearchesOlderThan(_clock().subtract(keepCacheFor)));

  /// Uma falha de leitura do cache não deve impedir a ida à rede.
  Future<T?> _readCache<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } on Object catch (e) {
      debugPrint('Falha ao ler o cache: $e');
      return null;
    }
  }

  /// Nem uma falha ao gravar o cache deve esconder um dado que já chegou.
  Future<void> _writeCache(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (e) {
      debugPrint('Falha ao gravar o cache: $e');
    }
  }
}
