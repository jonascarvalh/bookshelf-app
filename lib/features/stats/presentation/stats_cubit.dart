import 'dart:async';

import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:book_app/features/stats/domain/reading_stats.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recalcula as estatísticas sempre que a estante ou o histórico mudam.
class StatsCubit extends Cubit<ReadingStats?> {
  StatsCubit(ShelfRepository repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(null) {
    _subscriptions = [
      repository.watchShelf().listen((entries) {
        _entries = entries;
        _recompute();
      }),
      repository.watchLogs().listen((logs) {
        _logs = logs;
        _recompute();
      }),
    ];
  }

  final DateTime Function() _clock;
  late final List<StreamSubscription<Object>> _subscriptions;
  List<ShelfEntry>? _entries;
  List<ReadingLog>? _logs;

  void _recompute() {
    final entries = _entries;
    final logs = _logs;
    if (entries == null || logs == null) return;
    emit(ReadingStats.compute(entries: entries, logs: logs, now: _clock()));
  }

  @override
  Future<void> close() async {
    await Future.wait(_subscriptions.map((s) => s.cancel()));
    return super.close();
  }
}
