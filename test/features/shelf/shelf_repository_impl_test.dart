import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/features/shelf/data/repositories/shelf_repository_impl.dart';
import 'package:book_app/features/shelf/domain/entities/reading_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late ShelfRepositoryImpl repository;

  setUp(() {
    db = memoryDatabase();
    now = DateTime(2026, 10, 1, 9);
    repository = ShelfRepositoryImpl(db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<int>> loggedPages() async =>
      (await repository.watchLogs().first).map((l) => l.pages).toList();

  test('adiciona à estante como "Quero ler"', () async {
    await repository.setStatus(domCasmurro, ReadingStatus.wantToRead);

    final entry = (await repository.watchEntry(domCasmurro.id).first)!;
    expect(entry.status, ReadingStatus.wantToRead);
    expect(entry.book.title, 'Dom Casmurro');
    expect(entry.pages, 268);
    expect(entry.startedAt, isNull);
  });

  test('avançar o progresso registra as páginas lidas e começa a leitura', () async {
    await repository.setStatus(domCasmurro, ReadingStatus.wantToRead);
    await repository.updateProgress(domCasmurro.id, 40);
    now = now.add(const Duration(days: 1));
    await repository.updateProgress(domCasmurro.id, 100);
    await repository.updateProgress(domCasmurro.id, 90); // voltar não conta

    final entry = (await repository.watchEntry(domCasmurro.id).first)!;
    expect(entry.status, ReadingStatus.reading);
    expect(entry.currentPage, 90);
    expect(entry.startedAt, DateTime(2026, 10, 1, 9));
    expect(await loggedPages(), [40, 60]);
  });

  test('chegar à última página marca como lido', () async {
    await repository.setStatus(domCasmurro, ReadingStatus.reading);
    await repository.updateProgress(domCasmurro.id, 500);

    final entry = (await repository.watchEntry(domCasmurro.id).first)!;
    expect(entry.status, ReadingStatus.read);
    expect(entry.currentPage, 268);
    expect(entry.finishedAt, now);
    expect(entry.progress, 1);
  });

  test('marcar como lido registra as páginas que faltavam', () async {
    await repository.setStatus(domCasmurro, ReadingStatus.reading);
    await repository.updateProgress(domCasmurro.id, 68);
    await repository.setStatus(domCasmurro, ReadingStatus.read);

    expect(await loggedPages(), [68, 200]);
    final entry = (await repository.watchEntry(domCasmurro.id).first)!;
    expect(entry.currentPage, 268);
  });

  test('o usuário pode informar o total quando a API não tem', () async {
    final semPaginas = alienista.copyWith(pageCount: null);
    await repository.setStatus(semPaginas, ReadingStatus.reading);
    await repository.updateProgress(semPaginas.id, 30, totalPages: 120);

    final entry = (await repository.watchEntry(semPaginas.id).first)!;
    expect(entry.pages, 120);
    expect(entry.progress, 0.25);
  });

  test('a estante é ordenada pela última atualização', () async {
    await repository.setStatus(domCasmurro, ReadingStatus.wantToRead);
    now = now.add(const Duration(minutes: 1));
    await repository.setStatus(alienista, ReadingStatus.reading);

    final shelf = await repository.watchShelf().first;
    expect(shelf.map((e) => e.book.id), [alienista.id, domCasmurro.id]);

    await repository.remove(alienista.id);
    expect(await repository.watchShelf().first, hasLength(1));
  });

  test('atualizar um livro fora da estante falha sem lançar exceção', () async {
    final result = await repository.updateProgress('inexistente', 10);
    expect(result.isErr, isTrue);
  });
}
