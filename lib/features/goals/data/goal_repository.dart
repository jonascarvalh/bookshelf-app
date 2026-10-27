import 'package:book_app/features/goals/domain/reading_goal.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GoalRepository {
  ReadingGoal load();

  Future<void> save(ReadingGoal goal);
}

class PrefsGoalRepository implements GoalRepository {
  PrefsGoalRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _books = 'goal.books_per_year';
  static const _enabled = 'goal.reminder_enabled';
  static const _minutes = 'goal.reminder_minutes';

  @override
  ReadingGoal load() {
    const fallback = ReadingGoal();
    final minutes = _prefs.getInt(_minutes);
    return ReadingGoal(
      booksPerYear: _prefs.getInt(_books) ?? fallback.booksPerYear,
      reminderEnabled: _prefs.getBool(_enabled) ?? false,
      reminderHour: minutes == null ? fallback.reminderHour : minutes ~/ 60,
      reminderMinute: minutes == null ? fallback.reminderMinute : minutes % 60,
    );
  }

  @override
  Future<void> save(ReadingGoal goal) async {
    await _prefs.setInt(_books, goal.booksPerYear);
    await _prefs.setBool(_enabled, goal.reminderEnabled);
    await _prefs.setInt(_minutes, goal.reminderHour * 60 + goal.reminderMinute);
  }
}
