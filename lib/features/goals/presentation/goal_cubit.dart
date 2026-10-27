import 'package:book_app/core/notifications/reminder_scheduler.dart';
import 'package:book_app/features/goals/data/goal_repository.dart';
import 'package:book_app/features/goals/domain/reading_goal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_cubit.freezed.dart';

@freezed
abstract class GoalState with _$GoalState {
  const factory GoalState({
    required ReadingGoal goal,
    required bool remindersSupported,
    String? message,
  }) = _GoalState;
}

class GoalCubit extends Cubit<GoalState> {
  GoalCubit(this._repository, this._scheduler)
    : super(GoalState(goal: _repository.load(), remindersSupported: _scheduler.isSupported));

  final GoalRepository _repository;
  final ReminderScheduler _scheduler;

  Future<void> setBooksPerYear(int books) => _save(state.goal.copyWith(booksPerYear: books.clamp(1, 365)));

  Future<void> setReminderEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _scheduler.requestPermission();
      if (!granted) {
        emit(
          state.copyWith(
            message: 'Sem permissão para notificações. Ative nas configurações do aparelho.',
          ),
        );
        return;
      }
    }
    await _save(state.goal.copyWith(reminderEnabled: enabled));
  }

  Future<void> setReminderTime(int hour, int minute) =>
      _save(state.goal.copyWith(reminderHour: hour, reminderMinute: minute));

  void messageShown() => emit(state.copyWith(message: null));

  Future<void> _save(ReadingGoal goal) async {
    emit(state.copyWith(goal: goal));
    await _repository.save(goal);
    if (goal.reminderEnabled) {
      await _scheduler.scheduleDaily(hour: goal.reminderHour, minute: goal.reminderMinute);
    } else {
      await _scheduler.cancel();
    }
  }
}
