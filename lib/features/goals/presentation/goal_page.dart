import 'package:book_app/features/goals/presentation/goal_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GoalPage extends StatelessWidget {
  const GoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final cubit = context.read<GoalCubit>();

    return BlocConsumer<GoalCubit, GoalState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
        cubit.messageShown();
      },
      builder: (context, state) {
        final goal = state.goal;
        return Scaffold(
          appBar: AppBar(title: const Text('Meta e lembrete')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Meta para ${DateTime.now().year}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Quantos livros você quer terminar este ano?',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Diminuir',
                            onPressed: goal.booksPerYear > 1
                                ? () => cubit.setBooksPerYear(goal.booksPerYear - 1)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 110,
                            child: Column(
                              children: [
                                Text(
                                  '${goal.booksPerYear}',
                                  key: const Key('goal_value'),
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text('livros', style: theme.textTheme.labelLarge),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Aumentar',
                            onPressed: () => cubit.setBooksPerYear(goal.booksPerYear + 1),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _pace(goal.booksPerYear),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('reminder_switch'),
                      contentPadding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                      secondary: const Icon(Icons.notifications_active_rounded),
                      title: const Text('Lembrete diário'),
                      subtitle: Text(
                        state.remindersSupported
                            ? 'Uma notificação por dia para não perder o ritmo'
                            : 'Disponível no app para Android',
                      ),
                      value: goal.reminderEnabled,
                      onChanged: state.remindersSupported ? cubit.setReminderEnabled : null,
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                      enabled: goal.reminderEnabled,
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Horário'),
                      trailing: Text(goal.reminderLabel, style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: goal.reminderHour,
                            minute: goal.reminderMinute,
                          ),
                        );
                        if (time != null) await cubit.setReminderTime(time.hour, time.minute);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _pace(int books) {
    final perMonth = books / 12;
    if (perMonth >= 1) {
      final rounded = perMonth == perMonth.roundToDouble()
          ? perMonth.toInt().toString()
          : perMonth.toStringAsFixed(1).replaceAll('.', ',');
      return 'Cerca de $rounded ${perMonth == 1 ? 'livro' : 'livros'} por mês';
    }
    final months = (12 / books).round();
    return 'Um livro a cada $months meses';
  }
}
