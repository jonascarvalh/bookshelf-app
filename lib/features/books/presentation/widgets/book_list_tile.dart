import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/presentation/widgets/book_cover.dart';
import 'package:book_app/core/utils/formatters.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:flutter/material.dart';

/// Linha de resultado de busca.
class BookListTile extends StatelessWidget {
  const BookListTile({required this.book, required this.onTap, super.key});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final meta = [
      if (book.firstPublishYear case final year?) '$year',
      if (book.pageCount case final pages?) Formatters.plural(pages, 'página', 'páginas'),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Hero(
              tag: 'cover-${book.id}',
              child: BookCover(book: book, width: 56, size: CoverSize.small, radius: 6),
            ),
            const SizedBox(width: 16),
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
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}
