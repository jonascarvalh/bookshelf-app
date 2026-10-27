import 'dart:math' as math;

import 'package:book_app/core/utils/formatters.dart';
import 'package:book_app/features/goals/presentation/goal_cubit.dart';
import 'package:book_app/features/stats/domain/reading_stats.dart';
import 'package:book_app/features/stats/presentation/stats_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: BlocBuilder<StatsCubit, ReadingStats?>(
        builder: (context, stats) {
          if (stats == null) return const Center(child: CircularProgressIndicator());
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _GoalCard(stats: stats),
              const SizedBox(height: 12),
              // Cartões com a mesma altura mesmo quando um rótulo quebra a linha.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.local_fire_department_rounded,
                        value: '${stats.streakDays}',
                        label: stats.streakDays == 1 ? 'dia seguido' : 'dias seguidos',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.menu_book_rounded,
                        value: Formatters.number(stats.pagesThisMonth),
                        label: 'páginas este mês',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.auto_stories_rounded,
                        value: '${stats.readingNow}',
                        label: 'lendo agora',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Livros por mês',
                subtitle: 'Terminados nos últimos 6 meses',
                months: stats.months,
                value: (m) => m.booksFinished,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Páginas lidas',
                subtitle: '${Formatters.number(stats.pagesTotal)} páginas desde o início',
                months: stats.months,
                value: (m) => m.pagesRead,
                color: scheme.tertiary,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = context.select((GoalCubit c) => c.state.goal.booksPerYear);
    final done = stats.booksThisYear;
    final progress = (done / goal).clamp(0.0, 1.0);
    final remaining = math.max(goal - done, 0);

    return Card(
      color: scheme.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/goal'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: scheme.onPrimary,
                      backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta de ${DateTime.now().year}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$done de $goal livros',
                      key: const Key('goal_progress'),
                      style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining == 0
                          ? 'Meta batida! 🎉'
                          : 'Faltam ${Formatters.plural(remaining, 'livro', 'livros')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.tertiary),
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.titleLarge),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.months,
    required this.value,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<MonthStat> months;
  final int Function(MonthStat) value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final values = months.map(value).toList();
    final maxY = math.max(values.fold(0, math.max), 1).toDouble();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.15,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    // O valor fica acima de cada barra, sem eixo Y.
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (x, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            Formatters.number(values[x.toInt()]),
                            style: labelStyle?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (x, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            Formatters.monthShort(months[x.toInt()].month),
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i].toDouble(),
                            width: 22,
                            color: i == values.length - 1 ? color : color.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY * 1.15,
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
