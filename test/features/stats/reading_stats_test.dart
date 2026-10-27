import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/stats/domain/reading_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 10, 27, 20);

  ShelfEntry entry(ReadingStatus status, {DateTime? finishedAt}) => ShelfEntry(
    book: domCasmurro,
    status: status,
    addedAt: DateTime(2026),
    updatedAt: DateTime(2026),
    finishedAt: finishedAt,
  );

  ReadingLog log(DateTime at, int pages) => ReadingLog(bookId: 'x', pages: pages, loggedAt: at);

  test('agrupa livros terminados e páginas por mês, nos últimos 6 meses', () {
    final stats = ReadingStats.compute(
      now: now,
      entries: [
        entry(ReadingStatus.read, finishedAt: DateTime(2026, 10, 3)),
        entry(ReadingStatus.read, finishedAt: DateTime(2026, 8, 20)),
        entry(ReadingStatus.read, finishedAt: DateTime(2025, 12, 1)), // ano passado
        entry(ReadingStatus.reading),
        entry(ReadingStatus.wantToRead),
      ],
      logs: [
        log(DateTime(2026, 10, 1), 30),
        log(DateTime(2026, 10, 26), 20),
        log(DateTime(2026, 5, 10), 100),
        log(DateTime(2026, 4, 30), 999), // fora da janela
      ],
    );

    expect(stats.months.map((m) => m.month.month), [5, 6, 7, 8, 9, 10]);
    expect(stats.months.map((m) => m.booksFinished), [0, 0, 0, 1, 0, 1]);
    expect(stats.months.map((m) => m.pagesRead), [100, 0, 0, 0, 0, 50]);
    expect(stats.booksThisYear, 2);
    expect(stats.pagesThisMonth, 50);
    expect(stats.pagesTotal, 1149);
    expect(stats.readingNow, 1);
    expect(stats.wantToRead, 1);
  });

  test('a janela de meses atravessa a virada do ano', () {
    final stats = ReadingStats.compute(entries: [], logs: [], now: DateTime(2027, 2, 10));
    expect(stats.months.map((m) => '${m.month.year}-${m.month.month}'), [
      '2026-9',
      '2026-10',
      '2026-11',
      '2026-12',
      '2027-1',
      '2027-2',
    ]);
  });

  group('sequência de dias', () {
    test('conta dias seguidos até hoje', () {
      final stats = ReadingStats.compute(
        entries: [],
        now: now,
        logs: [
          log(DateTime(2026, 10, 27, 8), 5),
          log(DateTime(2026, 10, 26, 22), 5),
          log(DateTime(2026, 10, 25), 5),
          log(DateTime(2026, 10, 23), 5),
        ],
      );
      expect(stats.streakDays, 3);
    });

    test('ainda não ter lido hoje não zera a sequência', () {
      final stats = ReadingStats.compute(
        entries: [],
        now: now,
        logs: [log(DateTime(2026, 10, 26), 5), log(DateTime(2026, 10, 25), 5)],
      );
      expect(stats.streakDays, 2);
    });

    test('um dia sem leitura quebra a sequência', () {
      final stats = ReadingStats.compute(
        entries: [],
        now: now,
        logs: [log(DateTime(2026, 10, 24), 5)],
      );
      expect(stats.streakDays, 0);
    });
  });
}
