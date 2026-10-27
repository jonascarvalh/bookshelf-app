import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shelf_entry.freezed.dart';

/// Um livro na estante do usuário, com o progresso de leitura.
@freezed
abstract class ShelfEntry with _$ShelfEntry {
  const factory ShelfEntry({
    required Book book,
    required ReadingStatus status,
    @Default(0) int currentPage,
    int? totalPages,
    required DateTime addedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    required DateTime updatedAt,
  }) = _ShelfEntry;

  const ShelfEntry._();

  /// Total de páginas informado pelo usuário ou, na falta dele, o da API.
  int? get pages => totalPages ?? book.pageCount;

  /// Progresso entre 0 e 1.
  double get progress {
    if (status == ReadingStatus.read) return 1;
    final total = pages;
    if (total == null || total <= 0) return 0;
    return (currentPage / total).clamp(0, 1).toDouble();
  }
}

/// Páginas lidas em um momento, registradas a cada avanço de progresso.
@freezed
abstract class ReadingLog with _$ReadingLog {
  const factory ReadingLog({
    required String bookId,
    required int pages,
    required DateTime loggedAt,
  }) = _ReadingLog;
}
