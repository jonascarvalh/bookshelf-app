import 'package:book_app/core/result/result.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';

/// A estante fica só no aparelho; não depende de internet.
abstract interface class ShelfRepository {
  Stream<List<ShelfEntry>> watchShelf();

  Stream<ShelfEntry?> watchEntry(String bookId);

  Stream<List<ReadingLog>> watchLogs();

  /// Adiciona o livro à estante ou o move de prateleira.
  Future<Result<Unit>> setStatus(Book book, ReadingStatus status);

  /// Atualiza a página atual. Avançar registra as páginas lidas; chegar à
  /// última página marca o livro como lido.
  Future<Result<Unit>> updateProgress(String bookId, int currentPage, {int? totalPages});

  Future<Result<Unit>> remove(String bookId);
}
