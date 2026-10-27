import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_goal.freezed.dart';

/// Meta anual de livros e lembrete diário de leitura.
@freezed
abstract class ReadingGoal with _$ReadingGoal {
  const factory ReadingGoal({
    @Default(12) int booksPerYear,
    @Default(false) bool reminderEnabled,
    @Default(21) int reminderHour,
    @Default(0) int reminderMinute,
  }) = _ReadingGoal;

  const ReadingGoal._();

  String get reminderLabel =>
      '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}';
}
