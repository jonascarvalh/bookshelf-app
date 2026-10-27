import 'dart:convert';

import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Lista de textos guardada como JSON em uma coluna TEXT.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Cache dos livros vistos na busca, no scanner ou na estante.
@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authors => text().map(const StringListConverter())();
  IntColumn get coverId => integer().nullable()();
  IntColumn get firstPublishYear => integer().nullable()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get isbns => text().map(const StringListConverter())();
  TextColumn get subjects => text().map(const StringListConverter())();
  TextColumn get description => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Resultado de uma página de busca: a ordem dos ids e o total encontrado.
@DataClassName('SearchCacheRow')
class SearchCacheEntries extends Table {
  TextColumn get query => text()();
  IntColumn get page => integer()();
  TextColumn get bookIds => text().map(const StringListConverter())();
  IntColumn get totalCount => integer()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {query, page};
}

@DataClassName('ShelfRow')
class ShelfEntries extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get status => textEnum<ReadingStatus>()();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  IntColumn get totalPages => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

/// Cada avanço de progresso vira um registro, base das estatísticas.
@DataClassName('ReadingLogRow')
class ReadingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get pages => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}

@DriftDatabase(tables: [Books, SearchCacheEntries, ShelfEntries, ReadingLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Banco persistente no diretório de dados do app.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'estante'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
