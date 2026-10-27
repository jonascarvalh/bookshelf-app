import 'dart:async';

import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_details_cubit.freezed.dart';

@freezed
abstract class BookDetailsState with _$BookDetailsState {
  const factory BookDetailsState({
    Book? book,
    ShelfEntry? entry,
    @Default(true) bool isLoading,
    @Default(false) bool isRefreshing,

    /// Falha ao atualizar; se [book] existe, é só um aviso.
    Failure? failure,

    /// Mensagem de uma ação (ex.: erro ao salvar na estante).
    String? message,
  }) = _BookDetailsState;
}

class BookDetailsCubit extends Cubit<BookDetailsState> {
  BookDetailsCubit({
    required this.bookId,
    required this._books,
    required this._shelf,
    Book? initial,
  }) : super(BookDetailsState(book: initial, isLoading: initial == null)) {
    _load();
    _entrySubscription = _shelf.watchEntry(bookId).listen((entry) {
      emit(state.copyWith(entry: entry));
    });
  }

  final String bookId;
  final BookRepository _books;
  final ShelfRepository _shelf;
  StreamSubscription<Snapshot<Book>>? _bookSubscription;
  late final StreamSubscription<ShelfEntry?> _entrySubscription;

  void _load() {
    unawaited(_bookSubscription?.cancel());
    _bookSubscription = _books.watchBook(bookId).listen((snapshot) {
      emit(
        state.copyWith(
          book: snapshot.data ?? state.book,
          isLoading: false,
          isRefreshing: snapshot.isRefreshing,
          failure: snapshot.failure,
        ),
      );
    });
  }

  void retry() {
    emit(state.copyWith(isLoading: state.book == null, failure: null));
    _load();
  }

  Future<void> setStatus(ReadingStatus status) async {
    final book = state.book;
    if (book == null) return;
    final result = await _shelf.setStatus(book, status);
    if (result.isErr) emit(state.copyWith(message: result.failureOrNull!.message));
  }

  Future<void> updateProgress(int page, {int? totalPages}) async {
    final result = await _shelf.updateProgress(bookId, page, totalPages: totalPages);
    if (result.isErr) emit(state.copyWith(message: result.failureOrNull!.message));
  }

  Future<void> removeFromShelf() async {
    await _shelf.remove(bookId);
  }

  void messageShown() => emit(state.copyWith(message: null));

  @override
  Future<void> close() async {
    await _bookSubscription?.cancel();
    await _entrySubscription.cancel();
    return super.close();
  }
}
