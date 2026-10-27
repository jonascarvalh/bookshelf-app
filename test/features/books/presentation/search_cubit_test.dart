import 'package:bloc_test/bloc_test.dart';
import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/entities/search_page.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/features/books/presentation/search/search_cubit.dart';
import 'package:book_app/features/books/presentation/search/search_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBookRepository extends Mock implements BookRepository {}

List<Book> books(int from, int count) => [
  for (var i = from; i < from + count; i++) Book(id: 'OL${i}W', title: 'Livro $i'),
];

Snapshot<SearchPage> remotePage(int page, List<Book> items, {int total = 45}) => Snapshot(
  data: SearchPage(books: items, page: page, totalCount: total),
  origin: DataOrigin.remote,
);

void main() {
  late MockBookRepository repository;

  setUp(() => repository = MockBookRepository());

  SearchCubit build() => SearchCubit(repository, debounce: Duration.zero);

  blocTest<SearchCubit, SearchState>(
    'busca e mostra a primeira página',
    setUp: () => when(
      () => repository.search('machado', page: 1),
    ).thenAnswer((_) => Stream.value(remotePage(1, books(0, 20)))),
    build: build,
    act: (cubit) => cubit.search(' machado '),
    expect: () => [
      const SearchState(query: 'machado', status: SearchStatus.loading),
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.success)
          .having((s) => s.books.length, 'livros', 20)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'loadMore junta as páginas sem repetir livros',
    setUp: () {
      when(
        () => repository.search('machado', page: 1),
      ).thenAnswer((_) => Stream.value(remotePage(1, books(0, 20))));
      when(() => repository.search('machado', page: 2)).thenAnswer(
        // O livro 19 aparece de novo na página 2.
        (_) => Stream.value(remotePage(2, books(19, 20))),
      );
    },
    build: build,
    act: (cubit) async {
      cubit.search('machado');
      await Future<void>.delayed(Duration.zero);
      cubit.loadMore();
    },
    skip: 2,
    expect: () => [
      isA<SearchState>().having((s) => s.isLoadingMore, 'carregando', true),
      isA<SearchState>()
          .having((s) => s.books.length, 'livros', 39)
          .having((s) => s.isLoadingMore, 'carregando', false)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'mostra o cache enquanto a API responde e depois substitui',
    setUp: () => when(() => repository.search('machado', page: 1)).thenAnswer(
      (_) => Stream.fromIterable([
        Snapshot(
          data: SearchPage(books: books(0, 3), page: 1, totalCount: 3),
          origin: DataOrigin.cache,
          isRefreshing: true,
        ),
        remotePage(1, books(0, 5), total: 5),
      ]),
    ),
    build: build,
    act: (cubit) => cubit.search('machado'),
    skip: 1,
    expect: () => [
      isA<SearchState>()
          .having((s) => s.books.length, 'livros', 3)
          .having((s) => s.isRefreshing, 'atualizando', true),
      isA<SearchState>()
          .having((s) => s.books.length, 'livros', 5)
          .having((s) => s.isRefreshing, 'atualizando', false)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'cache com falha da API fica marcado como desatualizado',
    setUp: () => when(() => repository.search('machado', page: 1)).thenAnswer(
      (_) => Stream.value(
        Snapshot(
          data: SearchPage(books: books(0, 3), page: 1, totalCount: 3),
          origin: DataOrigin.cache,
          failure: const NoConnectionFailure(),
        ),
      ),
    ),
    build: build,
    act: (cubit) => cubit.search('machado'),
    skip: 1,
    expect: () => [
      isA<SearchState>()
          .having((s) => s.status, 'status', SearchStatus.success)
          .having((s) => s.isStale, 'stale', true),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'sem resultados vira estado vazio',
    setUp: () => when(
      () => repository.search('xyz', page: 1),
    ).thenAnswer((_) => Stream.value(remotePage(1, const [], total: 0))),
    build: build,
    act: (cubit) => cubit.search('xyz'),
    skip: 1,
    expect: () => [isA<SearchState>().having((s) => s.status, 'status', SearchStatus.empty)],
  );

  blocTest<SearchCubit, SearchState>(
    'falha sem cache vira estado de erro, e retry tenta de novo',
    setUp: () => when(() => repository.search('machado', page: 1)).thenAnswer(
      (_) => Stream.value(
        const Snapshot(origin: DataOrigin.cache, failure: TimeoutFailure()),
      ),
    ),
    build: build,
    act: (cubit) async {
      cubit.search('machado');
      await Future<void>.delayed(Duration.zero);
      await cubit.retry();
    },
    expect: () => [
      const SearchState(query: 'machado', status: SearchStatus.loading),
      const SearchState(
        query: 'machado',
        status: SearchStatus.failure,
        failure: TimeoutFailure(),
      ),
      const SearchState(query: 'machado', status: SearchStatus.loading),
      const SearchState(
        query: 'machado',
        status: SearchStatus.failure,
        failure: TimeoutFailure(),
      ),
    ],
    verify: (_) => verify(() => repository.search('machado', page: 1)).called(2),
  );

  blocTest<SearchCubit, SearchState>(
    'erro na página seguinte mantém a lista e permite tentar de novo',
    setUp: () {
      when(
        () => repository.search('machado', page: 1),
      ).thenAnswer((_) => Stream.value(remotePage(1, books(0, 20))));
      when(() => repository.search('machado', page: 2)).thenAnswer(
        (_) => Stream.value(
          const Snapshot(origin: DataOrigin.cache, failure: NoConnectionFailure()),
        ),
      );
    },
    build: build,
    act: (cubit) async {
      cubit.search('machado');
      await Future<void>.delayed(Duration.zero);
      cubit.loadMore();
    },
    skip: 3,
    expect: () => [
      isA<SearchState>()
          .having((s) => s.books.length, 'livros', 20)
          .having((s) => s.pageFailure, 'erro', const NoConnectionFailure())
          .having((s) => s.status, 'status', SearchStatus.success),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'textos curtos não disparam busca',
    build: build,
    act: (cubit) => cubit.search('a'),
    expect: () => [const SearchState(query: 'a')],
    verify: (_) => verifyNever(() => repository.search(any(), page: any(named: 'page'))),
  );

  test('debounce: só a última digitação vira busca', () async {
    when(
      () => repository.search(any(), page: any(named: 'page')),
    ).thenAnswer((_) => Stream.value(remotePage(1, books(0, 1), total: 1)));
    final cubit = SearchCubit(repository, debounce: const Duration(milliseconds: 50))
      ..queryChanged('ma')
      ..queryChanged('mac')
      ..queryChanged('machado');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    verify(() => repository.search('machado', page: 1)).called(1);
    verifyNever(() => repository.search('mac', page: 1));
    await cubit.close();
  });
}
