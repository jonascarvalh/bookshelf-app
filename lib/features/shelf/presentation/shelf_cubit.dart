import 'dart:async';

import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shelf_cubit.freezed.dart';

@freezed
abstract class ShelfState with _$ShelfState {
  const factory ShelfState({
    @Default(true) bool isLoading,
    @Default(<ShelfEntry>[]) List<ShelfEntry> entries,
  }) = _ShelfState;

  const ShelfState._();

  List<ShelfEntry> byStatus(ReadingStatus status) =>
      entries.where((e) => e.status == status).toList();
}

/// A estante vem do banco local via `watch`, então reflete na hora qualquer
/// mudança feita em outra tela.
class ShelfCubit extends Cubit<ShelfState> {
  ShelfCubit(ShelfRepository repository) : super(const ShelfState()) {
    _subscription = repository.watchShelf().listen(
      (entries) => emit(ShelfState(isLoading: false, entries: entries)),
    );
  }

  late final StreamSubscription<List<ShelfEntry>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
