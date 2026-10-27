import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/presentation/widgets/book_cover.dart';
import 'package:book_app/core/presentation/widgets/state_views.dart';
import 'package:book_app/core/utils/formatters.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/presentation/details/book_details_cubit.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/presentation/progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookDetailsCubit, BookDetailsState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
        context.read<BookDetailsCubit>().messageShown();
      },
      builder: (context, state) {
        final book = state.book;
        return Scaffold(
          appBar: AppBar(
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: 'Início',
                    icon: const Icon(Icons.home_rounded),
                    onPressed: () => context.go('/shelf'),
                  ),
            actions: [
              if (state.entry != null)
                PopupMenuButton<void>(
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: context.read<BookDetailsCubit>().removeFromShelf,
                      child: const Text('Remover da estante'),
                    ),
                  ],
                ),
            ],
          ),
          body: switch ((book, state.isLoading)) {
            (null, true) => const Center(child: CircularProgressIndicator()),
            (null, false) => MessageView.error(
              message: state.failure?.message ?? 'Livro não encontrado.',
              onRetry: context.read<BookDetailsCubit>().retry,
            ),
            (final Book book, _) => _Details(book: book, state: state),
          },
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.book, required this.state});

  final Book book;
  final BookDetailsState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isbn = book.isbns.where((i) => i.length == 13).firstOrNull ?? book.isbns.firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Center(
          child: Hero(
            tag: 'cover-${book.id}',
            child: BookCover(book: book, width: 148, size: CoverSize.large, radius: 10),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          book.authors.isEmpty ? 'Autor desconhecido' : book.authors.join(', '),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(color: muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (book.firstPublishYear case final year?)
              _MetaChip(icon: Icons.event_rounded, label: '$year'),
            if (book.pageCount case final pages?)
              _MetaChip(icon: Icons.auto_stories_rounded, label: '$pages págs.'),
            if (isbn != null) _MetaChip(icon: Icons.qr_code_2_rounded, label: isbn),
          ],
        ),
        const SizedBox(height: 22),
        _ShelfCard(entry: state.entry),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Sinopse', style: theme.textTheme.titleMedium),
            const SizedBox(width: 10),
            if (state.isRefreshing)
              const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          book.description ??
              switch (state.failure) {
                _ when state.isRefreshing => 'Carregando…',
                NoConnectionFailure() => 'A sinopse aparece quando você abrir este livro com internet.',
                Failure() => 'Não foi possível carregar a sinopse agora.',
                null => 'A Open Library não tem sinopse para esta obra.',
              },
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: book.description == null ? muted : null,
          ),
        ),
        if (book.subjects.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Assuntos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in book.subjects.take(6))
                Chip(label: Text(s), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.entry});

  final ShelfEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<BookDetailsCubit>();
    final entry = this.entry;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry == null ? 'Adicionar à estante' : 'Na sua estante',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ReadingStatus>(
              key: const Key('status_selector'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final status in ReadingStatus.values)
                  ButtonSegment(value: status, label: Text(status.label)),
              ],
              selected: {?entry?.status},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) cubit.setStatus(selection.first);
              },
            ),
            if (entry != null && entry.status != ReadingStatus.wantToRead) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.pages == null
                          ? 'Página ${entry.currentPage}'
                          : 'Página ${entry.currentPage} de ${entry.pages}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${(entry.progress * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: entry.progress, minHeight: 8),
              if (entry.status == ReadingStatus.read && entry.finishedAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Terminado em ${Formatters.dayMonth(entry.finishedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              if (entry.status == ReadingStatus.reading) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('update_progress_button'),
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: const Text('Atualizar progresso'),
                  onPressed: () async {
                    final result = await showProgressDialog(context, entry);
                    if (result != null) {
                      await cubit.updateProgress(result.page, totalPages: result.totalPages);
                    }
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
