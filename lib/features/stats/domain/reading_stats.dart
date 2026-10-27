import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_stats.freezed.dart';

@freezed
abstract class MonthStat with _$MonthStat {
  const factory MonthStat({
    /// Primeiro dia do mês.
    required DateTime month,
    required int booksFinished,
    required int pagesRead,
  }) = _MonthStat;
}

@freezed
abstract class ReadingStats with _$ReadingStats {
  const factory ReadingStats({
    /// Últimos meses, do mais antigo para o atual.
    required List<MonthStat> months,
    required int booksThisYear,
    required int pagesThisMonth,
    required int pagesTotal,
    required int readingNow,
    required int wantToRead,

    /// Dias seguidos (até hoje ou ontem) com alguma página registrada.
    required int streakDays,
  }) = _ReadingStats;

  /// Calcula as estatísticas a partir da estante e do histórico de leitura.
  /// É uma função pura, sem acesso a banco, para ser fácil de testar.
  factory ReadingStats.compute({
    required List<ShelfEntry> entries,
    required List<ReadingLog> logs,
    required DateTime now,
    int monthCount = 6,
  }) {
    DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
    final currentMonth = monthOf(now);

    final months = [
      for (var i = monthCount - 1; i >= 0; i--)
        DateTime(currentMonth.year, currentMonth.month - i),
    ];
    final finishedByMonth = <DateTime, int>{};
    final pagesByMonth = <DateTime, int>{};

    for (final entry in entries) {
      final finished = entry.finishedAt;
      if (entry.status == ReadingStatus.read && finished != null) {
        finishedByMonth.update(monthOf(finished), (v) => v + 1, ifAbsent: () => 1);
      }
    }
    for (final log in logs) {
      pagesByMonth.update(monthOf(log.loggedAt), (v) => v + log.pages, ifAbsent: () => log.pages);
    }

    return ReadingStats(
      months: [
        for (final m in months)
          MonthStat(
            month: m,
            booksFinished: finishedByMonth[m] ?? 0,
            pagesRead: pagesByMonth[m] ?? 0,
          ),
      ],
      booksThisYear: entries
          .where((e) => e.status == ReadingStatus.read && e.finishedAt?.year == now.year)
          .length,
      pagesThisMonth: pagesByMonth[currentMonth] ?? 0,
      pagesTotal: logs.fold(0, (sum, l) => sum + l.pages),
      readingNow: entries.where((e) => e.status == ReadingStatus.reading).length,
      wantToRead: entries.where((e) => e.status == ReadingStatus.wantToRead).length,
      streakDays: _streak(logs, now),
    );
  }

  static int _streak(List<ReadingLog> logs, DateTime now) {
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
    final days = {for (final l in logs) if (l.pages > 0) dayOf(l.loggedAt)};

    var day = dayOf(now);
    // Ainda não ler hoje não quebra a sequência de ontem.
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);

    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }
}
