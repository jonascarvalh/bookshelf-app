import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:drift/drift.dart';

/// Página de busca salva no aparelho.
typedef CachedSearch = ({List<Book> books, int totalCount, DateTime cachedAt});

abstract interface class BookLocalDataSource {
  Future<CachedSearch?> getSearch(String query, int page);

  Future<void> saveSearch(String query, int page, List<Book> books, int totalCount);

  Future<(Book, DateTime)?> getBook(String id);

  Future<Book?> findByIsbn(String isbn);

  /// Grava o livro preservando campos que só o cache tem (ex.: sinopse que
  /// a busca não traz).
  Future<void> upsertBooks(List<Book> books);

  Future<void> deleteSearchesOlderThan(DateTime limit);
}

class DriftBookLocalDataSource implements BookLocalDataSource {
  DriftBookLocalDataSource(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<CachedSearch?> getSearch(String query, int page) async {
    final row =
        await (_db.select(_db.searchCacheEntries)
              ..where((t) => t.query.equals(query) & t.page.equals(page)))
            .getSingleOrNull();
    if (row == null) return null;

    final books = await (_db.select(_db.books)..where((t) => t.id.isIn(row.bookIds))).get();
    final byId = {for (final b in books) b.id: rowToBook(b)};
    // Mantém a ordem original da API.
    final ordered = [for (final id in row.bookIds) ?byId[id]];
    return (books: ordered, totalCount: row.totalCount, cachedAt: row.cachedAt);
  }

  @override
  Future<void> saveSearch(String query, int page, List<Book> books, int totalCount) {
    return _db.transaction(() async {
      await upsertBooks(books);
      await _db
          .into(_db.searchCacheEntries)
          .insertOnConflictUpdate(
            SearchCacheEntriesCompanion.insert(
              query: query,
              page: page,
              bookIds: [for (final b in books) b.id],
              totalCount: totalCount,
              cachedAt: _clock(),
            ),
          );
    });
  }

  @override
  Future<(Book, DateTime)?> getBook(String id) async {
    final row = await (_db.select(_db.books)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : (rowToBook(row), row.updatedAt);
  }

  @override
  Future<Book?> findByIsbn(String isbn) async {
    final row =
        await (_db.select(_db.books)
              ..where((t) => t.isbns.like('%"$isbn"%'))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : rowToBook(row);
  }

  @override
  Future<void> upsertBooks(List<Book> books) async {
    if (books.isEmpty) return;
    final existing = await (_db.select(
      _db.books,
    )..where((t) => t.id.isIn(books.map((b) => b.id)))).get();
    final descriptions = {for (final r in existing) r.id: r.description};

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.books, [
        for (final book in books)
          bookToCompanion(
            book.description == null ? book.copyWith(description: descriptions[book.id]) : book,
            _clock(),
          ),
      ]);
    });
  }

  @override
  Future<void> deleteSearchesOlderThan(DateTime limit) async {
    await (_db.delete(
      _db.searchCacheEntries,
    )..where((t) => t.cachedAt.isSmallerThanValue(limit))).go();
    // Livros que não estão em nenhuma busca nem na estante saem do cache.
    await _db.customStatement('''
      DELETE FROM books
      WHERE id NOT IN (SELECT book_id FROM shelf_entries)
        AND updated_at < ?
    ''', [limit.millisecondsSinceEpoch ~/ 1000]);
  }
}

Book rowToBook(BookRow row) => Book(
  id: row.id,
  title: row.title,
  authors: row.authors,
  coverId: row.coverId,
  firstPublishYear: row.firstPublishYear,
  pageCount: row.pageCount,
  isbns: row.isbns,
  subjects: row.subjects,
  description: row.description,
);

BooksCompanion bookToCompanion(Book book, DateTime now) => BooksCompanion.insert(
  id: book.id,
  title: book.title,
  authors: book.authors,
  coverId: Value(book.coverId),
  firstPublishYear: Value(book.firstPublishYear),
  pageCount: Value(book.pageCount),
  isbns: book.isbns,
  subjects: book.subjects,
  description: Value(book.description),
  updatedAt: now,
);
