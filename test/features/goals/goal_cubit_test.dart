import 'package:book_app/features/goals/data/goal_repository.dart';
import 'package:book_app/features/goals/presentation/goal_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('salva a meta e o horário do lembrete', () async {
    final scheduler = FakeReminderScheduler();
    final cubit = GoalCubit(PrefsGoalRepository(prefs), scheduler);

    await cubit.setBooksPerYear(20);
    await cubit.setReminderEnabled(true);
    await cubit.setReminderTime(7, 30);

    final saved = PrefsGoalRepository(prefs).load();
    expect(saved.booksPerYear, 20);
    expect(saved.reminderEnabled, isTrue);
    expect(saved.reminderLabel, '07:30');
    expect(scheduler.calls, ['cancel', 'permission', 'schedule 21:0', 'schedule 7:30']);
  });

  test('sem permissão o lembrete continua desligado e o usuário é avisado', () async {
    final scheduler = FakeReminderScheduler(grantPermission: false);
    final cubit = GoalCubit(PrefsGoalRepository(prefs), scheduler);

    await cubit.setReminderEnabled(true);

    expect(cubit.state.goal.reminderEnabled, isFalse);
    expect(cubit.state.message, contains('permissão'));
    expect(scheduler.calls, ['permission']);
  });

  test('desligar cancela o lembrete agendado', () async {
    final scheduler = FakeReminderScheduler();
    final cubit = GoalCubit(PrefsGoalRepository(prefs), scheduler);

    await cubit.setReminderEnabled(true);
    await cubit.setReminderEnabled(false);

    expect(scheduler.calls.last, 'cancel');
  });
}
