import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/presentation/widgets/book_cover.dart';
import 'package:book_app/core/presentation/widgets/state_views.dart';
import 'package:book_app/core/utils/formatters.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/presentation/shelf_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ShelfPage extends StatelessWidget {
  const ShelfPage({super.key});

  static const _tabs = [ReadingStatus.reading, ReadingStatus.wantToRead, ReadingStatus.read];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShelfCubit, ShelfState>(
      builder: (context, state) {
        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Minha estante'),
              actions: [
                IconButton(
                  tooltip: 'Meta e lembrete',
                  icon: const Icon(Icons.flag_rounded),
                  onPressed: () => context.push('/goal'),
                ),
                const SizedBox(width: 4),
              ],
              bottom: TabBar(
                tabAlignment: TabAlignment.fill,
                tabs: [
                  for (final status in _tabs)
                    Tab(text: '${status.label} · ${state.byStatus(status).length}'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('scan_fab'),
              onPressed: () => context.push('/scan'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear'),
            ),
            body: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      for (final status in _tabs)
                        _ShelfList(status: status, entries: state.byStatus(status)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ShelfList extends StatelessWidget {
  const _ShelfList({required this.status, required this.entries});

  final ReadingStatus status;
  final List<ShelfEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return MessageView(
        icon: switch (status) {
          ReadingStatus.reading => Icons.auto_stories_rounded,
          ReadingStatus.wantToRead => Icons.bookmark_border_rounded,
          ReadingStatus.read => Icons.task_alt_rounded,
        },
        title: switch (status) {
          ReadingStatus.reading => 'Nenhuma leitura em andamento',
          ReadingStatus.wantToRead => 'Sua lista de desejos está vazia',
          ReadingStatus.read => 'Nenhum livro lido ainda',
        },
        message: 'Busque um livro ou escaneie o código de barras para começar.',
        actionLabel: 'Buscar livros',
        onAction: () => context.go('/search'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ShelfTile(entry: entries[index]),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.entry});

  final ShelfEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final book = entry.book;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/book/${book.id}', extra: book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Sem Hero: a aba de busca fica viva ao lado desta (IndexedStack) e
              // já usa a mesma tag para o mesmo livro.
              BookCover(book: book, width: 64, size: CoverSize.small, radius: 6),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 10),
                    ..._details(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _details(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    switch (entry.status) {
      case ReadingStatus.reading:
        return [
          LinearProgressIndicator(value: entry.progress, minHeight: 6),
          const SizedBox(height: 6),
          Text(
            entry.pages == null
                ? 'Página ${entry.currentPage}'
                : 'Página ${entry.currentPage} de ${entry.pages} · '
                      '${(entry.progress * 100).round()}%',
            style: small,
          ),
        ];
      case ReadingStatus.wantToRead:
        return [Text('Adicionado em ${Formatters.dayMonth(entry.addedAt)}', style: small)];
      case ReadingStatus.read:
        return [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                entry.finishedAt == null
                    ? 'Lido'
                    : 'Lido em ${Formatters.monthYear(entry.finishedAt!)}',
                style: small,
              ),
            ],
          ),
        ];
    }
  }
}
