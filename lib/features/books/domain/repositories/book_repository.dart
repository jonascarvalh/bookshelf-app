import 'package:book_app/core/result/result.dart';
import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/entities/search_page.dart';

abstract interface class BookRepository {
  /// Busca por título ou autor. Emite o cache primeiro (se houver) e depois
  /// a resposta da API. Veja [Snapshot].
  Stream<Snapshot<SearchPage>> search(String query, {int page = 1});

  /// Detalhes de uma obra: cache imediato e, em seguida, a sinopse da API.
  Stream<Snapshot<Book>> watchBook(String id);

  /// Encontra a obra de um ISBN, procurando primeiro no aparelho.
  Future<Result<Book>> findByIsbn(String isbn);

  /// Salva um livro no cache (ex.: ao abrir um resultado de busca).
  Future<void> save(Book book);

  /// Remove buscas antigas do cache. Livros na estante nunca são removidos.
  Future<void> evictStaleCache();
}
