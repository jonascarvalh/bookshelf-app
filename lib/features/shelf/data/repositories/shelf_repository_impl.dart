import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/result/result.dart';
import 'package:book_app/features/books/data/datasources/book_local_data_source.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class ShelfRepositoryImpl implements ShelfRepository {
  ShelfRepositoryImpl(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  JoinedSelectStatement<HasResultSet, dynamic> _joined() => _db.select(_db.shelfEntries).join([
    innerJoin(_db.books, _db.books.id.equalsExp(_db.shelfEntries.bookId)),
  ]);

  ShelfEntry _toEntry(TypedResult row) {
    final shelf = row.readTable(_db.shelfEntries);
    return ShelfEntry(
      book: rowToBook(row.readTable(_db.books)),
      status: shelf.status,
      currentPage: shelf.currentPage,
      totalPages: shelf.totalPages,
      addedAt: shelf.addedAt,
      startedAt: shelf.startedAt,
      finishedAt: shelf.finishedAt,
      updatedAt: shelf.updatedAt,
    );
  }

  @override
  Stream<List<ShelfEntry>> watchShelf() {
    final query = _joined()..orderBy([OrderingTerm.desc(_db.shelfEntries.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toEntry).toList());
  }

  @override
  Stream<ShelfEntry?> watchEntry(String bookId) {
    final query = _joined()..where(_db.shelfEntries.bookId.equals(bookId));
    return query.watchSingleOrNull().map((row) => row == null ? null : _toEntry(row));
  }

  @override
  Stream<List<ReadingLog>> watchLogs() {
    return _db.select(_db.readingLogs).watch().map(
      (rows) => [
        for (final r in rows) ReadingLog(bookId: r.bookId, pages: r.pages, loggedAt: r.loggedAt),
      ],
    );
  }

  @override
  Future<Result<Unit>> setStatus(Book book, ReadingStatus status) => _guard(() async {
    final now = _clock();
    // O livro normalmente já está no cache; se não estiver, entra agora.
    await _db
        .into(_db.books)
        .insert(bookToCompanion(book, now), mode: InsertMode.insertOrIgnore);
    final current = await _find(book.id);
    final total = current?.totalPages ?? book.pageCount;
    final page = current?.currentPage ?? 0;

    if (status == ReadingStatus.read && total != null && total > page) {
      await _log(book.id, total - page, now);
    }

    await _db
        .into(_db.shelfEntries)
        .insertOnConflictUpdate(
          ShelfEntriesCompanion.insert(
            bookId: book.id,
            status: status,
            currentPage: Value(switch (status) {
              ReadingStatus.wantToRead => 0,
              ReadingStatus.reading => page,
              ReadingStatus.read => total ?? page,
            }),
            totalPages: Value(total),
            addedAt: current?.addedAt ?? now,
            startedAt: Value(
              status == ReadingStatus.wantToRead ? null : (current?.startedAt ?? now),
            ),
            finishedAt: Value(status == ReadingStatus.read ? now : null),
            updatedAt: now,
          ),
        );
  });

  @override
  Future<Result<Unit>> updateProgress(String bookId, int currentPage, {int? totalPages}) =>
      _guard(() async {
        final current = await _find(bookId);
        if (current == null) throw StateError('Livro $bookId não está na estante');

        final now = _clock();
        final book = await (_db.select(
          _db.books,
        )..where((t) => t.id.equals(bookId))).getSingle();
        final total = totalPages ?? current.totalPages ?? book.pageCount;
        final page = total == null ? currentPage.clamp(0, 99999) : currentPage.clamp(0, total);

        final delta = page - current.currentPage;
        if (delta > 0) await _log(bookId, delta, now);

        final finished = total != null && total > 0 && page >= total;
        final status = finished
            ? ReadingStatus.read
            : (page > 0 ? ReadingStatus.reading : current.status);

        await (_db.update(_db.shelfEntries)..where((t) => t.bookId.equals(bookId))).write(
          ShelfEntriesCompanion(
            currentPage: Value(page),
            totalPages: Value(total),
            status: Value(status),
            startedAt: Value(current.startedAt ?? (page > 0 ? now : null)),
            finishedAt: Value(finished ? (current.finishedAt ?? now) : null),
            updatedAt: Value(now),
          ),
        );
      });

  @override
  Future<Result<Unit>> remove(String bookId) => _guard(() async {
    await (_db.delete(_db.shelfEntries)..where((t) => t.bookId.equals(bookId))).go();
  });

  Future<ShelfRow?> _find(String bookId) =>
      (_db.select(_db.shelfEntries)..where((t) => t.bookId.equals(bookId))).getSingleOrNull();

  Future<void> _log(String bookId, int pages, DateTime at) => _db
      .into(_db.readingLogs)
      .insert(ReadingLogsCompanion.insert(bookId: bookId, pages: pages, loggedAt: at));

  Future<Result<Unit>> _guard(Future<void> Function() action) async {
    try {
      await _db.transaction(action);
      return const Ok(unit);
    } on Object catch (e) {
      debugPrint('Erro na estante: $e');
      return const Err(CacheFailure());
    }
  }
}
