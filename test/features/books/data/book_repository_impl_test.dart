import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/network/dio_factory.dart';
import 'package:book_app/core/result/result.dart';
import 'package:book_app/core/result/snapshot.dart';
import 'package:book_app/features/books/data/datasources/book_local_data_source.dart';
import 'package:book_app/features/books/data/datasources/book_remote_data_source.dart';
import 'package:book_app/features/books/data/repositories/book_repository_impl.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_open_library.dart';
import '../../../helpers/fakes.dart';

/// O repositório é testado com o banco real (SQLite em memória) e a API
/// simulada no nível HTTP, para cobrir também a serialização.
void main() {
  late AppDatabase db;
  late FakeHttpAdapter api;
  late FakeConnectivity connectivity;
  late DateTime now;
  late BookRepositoryImpl repository;

  setUp(() {
    db = memoryDatabase();
    api = FakeHttpAdapter(openLibraryHandler);
    connectivity = FakeConnectivity();
    now = DateTime(2026, 10, 27, 10);
    repository = BookRepositoryImpl(
      remote: OpenLibraryRemoteDataSource(DioFactory.create(adapter: api, sleep: (_) async {})),
      local: DriftBookLocalDataSource(db, clock: () => now),
      connectivity: connectivity,
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  group('search', () {
    test('sem cache: vai à API e salva o resultado', () async {
      final snapshots = await repository.search('Machado de Assis').toList();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.origin, DataOrigin.remote);
      expect(snapshots.single.data!.books.first.title, 'Dom Casmurro');
      expect(snapshots.single.data!.hasMore, isTrue);

      final cached = await DriftBookLocalDataSource(db).getSearch('machado de assis', 1);
      expect(cached!.books, hasLength(20));
    });

    test('cache recente: responde só com o cache, sem chamar a API', () async {
      await repository.search('machado de assis').drain<void>();
      api.requests.clear();
      now = now.add(const Duration(minutes: 10));

      final snapshots = await repository.search('  MACHADO  de assis ').toList();

      expect(snapshots.single.origin, DataOrigin.cache);
      expect(snapshots.single.isRefreshing, isFalse);
      expect(api.requests, isEmpty);
    });

    test('cache antigo: mostra o cache e depois a resposta nova', () async {
      await repository.search('machado de assis').drain<void>();
      now = now.add(const Duration(hours: 2));

      final snapshots = await repository.search('machado de assis').toList();

      expect(snapshots.map((s) => s.origin), [DataOrigin.cache, DataOrigin.remote]);
      expect(snapshots.first.isRefreshing, isTrue);
      expect(snapshots.first.data!.books, hasLength(20));
    });

    test('API falha com cache: mantém o cache e informa a falha', () async {
      await repository.search('machado de assis').drain<void>();
      now = now.add(const Duration(hours: 2));
      api.handler = (o) => throw receiveTimeout(o);

      final last = (await repository.search('machado de assis').toList()).last;

      expect(last.isStale, isTrue);
      expect(last.failure, const TimeoutFailure());
      expect(last.data!.books.first.title, 'Dom Casmurro');
    });

    test('offline: não tenta a rede', () async {
      connectivity.online = false;

      final snapshots = await repository.search('machado de assis').toList();

      expect(snapshots.single.data, isNull);
      expect(snapshots.single.failure, const NoConnectionFailure());
      expect(api.requests, isEmpty);
    });

    test('páginas ficam em cache separadamente', () async {
      final page2 = (await repository.search('machado de assis', page: 2).toList()).single;
      expect(page2.data!.page, 2);
      expect(page2.data!.books.first.title, 'Vidas secas');
      expect(api.requests.single.queryParameters['page'], 2);
    });
  });

  group('watchBook', () {
    test('mostra o livro do cache e completa com a sinopse da API', () async {
      await repository.search('machado de assis').drain<void>();

      final snapshots = await repository.watchBook('OL1003040W').toList();

      expect(snapshots.first.data!.description, isNull);
      expect(snapshots.first.isRefreshing, isTrue);
      expect(snapshots.last.data!.description, startsWith('Dom Casmurro, publicado'));
      expect(snapshots.last.data!.coverId, 647501);
    });

    test('a sinopse fica salva para uso offline', () async {
      await repository.search('machado de assis').drain<void>();
      await repository.watchBook('OL1003040W').drain<void>();

      connectivity.online = false;
      final snapshots = await repository.watchBook('OL1003040W').toList();

      expect(snapshots.single.origin, DataOrigin.cache);
      expect(snapshots.single.data!.description, isNotNull);
    });

    test('a busca não apaga a sinopse já salva', () async {
      await repository.search('machado de assis').drain<void>();
      await repository.watchBook('OL1003040W').drain<void>();
      now = now.add(const Duration(hours: 2));
      await repository.search('machado de assis').drain<void>();

      final (book, _) = (await DriftBookLocalDataSource(db).getBook('OL1003040W'))!;
      expect(book.description, isNotNull);
    });
  });

  group('findByIsbn', () {
    test('encontra pela API e normaliza o ISBN', () async {
      final result = await repository.findByIsbn('978-85-00-50700-7');

      expect(result.valueOrNull?.title, 'Dom Casmurro');
      expect(api.requests.single.queryParameters['isbn'], '9788500507007');
    });

    test('procura primeiro no aparelho', () async {
      await repository.findByIsbn('9788500507007');
      api.requests.clear();
      connectivity.online = false;

      final result = await repository.findByIsbn('9788500507007');

      expect(result, isA<Ok<Book>>());
      expect(api.requests, isEmpty);
    });

    test('ISBN desconhecido vira NotFoundFailure', () async {
      final result = await repository.findByIsbn('9780000000002');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('offline e fora do cache vira NoConnectionFailure', () async {
      connectivity.online = false;
      final result = await repository.findByIsbn('9788500507007');
      expect(result.failureOrNull, const NoConnectionFailure());
    });
  });

  test('evictStaleCache apaga buscas antigas', () async {
    await repository.search('machado de assis').drain<void>();
    now = now.add(const Duration(days: 31));

    await repository.evictStaleCache();

    expect(await DriftBookLocalDataSource(db).getSearch('machado de assis', 1), isNull);
    expect(await db.select(db.books).get(), isEmpty);
  });
}
