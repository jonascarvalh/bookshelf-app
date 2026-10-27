import 'dart:convert';

import 'package:book_app/core/error/exceptions.dart';
import 'package:book_app/core/network/dio_factory.dart';
import 'package:book_app/features/books/data/datasources/book_remote_data_source.dart';
import 'package:book_app/features/books/data/models/search_response_dto.dart';
import 'package:book_app/features/books/data/models/work_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_open_library.dart';

void main() {
  group('DTOs', () {
    test('lê a resposta de busca e converte para a entidade', () {
      final dto = SearchResponseDto.fromJson(
        jsonDecode(fixture('search_page1.json')) as Map<String, dynamic>,
      );

      expect(dto.numFound, 1406);
      expect(dto.docs, hasLength(20));

      final book = dto.docs.first.toEntity();
      expect(book.id, 'OL1003040W');
      expect(book.title, 'Dom Casmurro');
      expect(book.authors, ['Machado de Assis']);
      expect(book.coverId, 647501);
      expect(book.pageCount, 268);
      expect(book.firstPublishYear, 1900);
    });

    test('campos ausentes viram valores padrão', () {
      final doc = SearchDocDto.fromJson(const {'key': '/works/OL1W', 'title': ' Sem dados '});
      final book = doc.toEntity();

      expect(book.title, 'Sem dados');
      expect(book.authors, isEmpty);
      expect(book.coverId, isNull);
      expect(book.authorsLabel, 'Autor desconhecido');
    });

    test('remove autores repetidos', () {
      final doc = SearchDocDto.fromJson(const {
        'key': '/works/OL1W',
        'title': 'X',
        'author_name': ['Machado de Assis', 'Machado de Assis '],
      });
      expect(doc.toEntity().authors, ['Machado de Assis']);
    });

    test('sinopse pode vir como texto ou como objeto', () {
      final plain = WorkDto.fromJson(jsonDecode(fixture('work.json')) as Map<String, dynamic>);
      expect(plain.description, startsWith('Dom Casmurro, publicado'));

      final object = WorkDto.fromJson(
        jsonDecode(fixture('work_description_object.json')) as Map<String, dynamic>,
      );
      expect(object.description, 'Simão Bacamarte funda um hospício em Itaguaí.');
      expect(object.covers, [-1, 647504]);
    });

    test('remove o Markdown da sinopse', () {
      const raw = '**Helena** é um romance de [Machado](https://pt.wikipedia.org/wiki/Machado) '
          '([fonte][1]).\r\n\r\n\r\n\r\nSegundo parágrafo.\r\n\r\n[1]: https://example.com';
      expect(
        const DescriptionConverter().fromJson(raw),
        'Helena é um romance de Machado (fonte).\n\nSegundo parágrafo.',
      );
      expect(const DescriptionConverter().fromJson('   '), isNull);
      expect(const DescriptionConverter().fromJson(42), isNull);
    });
  });

  group('OpenLibraryRemoteDataSource', () {
    late FakeHttpAdapter adapter;
    late OpenLibraryRemoteDataSource remote;

    setUp(() {
      adapter = FakeHttpAdapter(openLibraryHandler);
      remote = OpenLibraryRemoteDataSource(
        DioFactory.create(adapter: adapter, sleep: (_) async {}),
      );
    });

    test('envia busca, página, limite e campos', () async {
      await remote.search('machado de assis', page: 2);

      final request = adapter.requests.single;
      expect(request.path, '/search.json');
      expect(request.queryParameters, containsPair('q', 'machado de assis'));
      expect(request.queryParameters, containsPair('page', 2));
      expect(request.queryParameters, containsPair('limit', 20));
      expect(request.queryParameters['fields'], contains('cover_i'));
      expect(request.headers['User-Agent'], startsWith('Estante/'));
    });

    test('ISBN inexistente retorna null', () async {
      expect(await remote.findByIsbn('9780000000002'), isNull);
      expect((await remote.findByIsbn('9788500507007'))?.title, 'Dom Casmurro');
    });

    test('converte falhas de rede em ApiException', () async {
      adapter.handler = (o) => throw receiveTimeout(o);
      await expectLater(
        remote.search('x', page: 1),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout)),
      );

      adapter.handler = (o) => throw connectionError(o);
      await expectLater(
        remote.search('x', page: 1),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noConnection)),
      );

      adapter.handler = (_) => const FakeResponse('{}', 500);
      await expectLater(
        remote.search('x', page: 1),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });

    test('JSON com formato inesperado vira invalidResponse', () async {
      adapter.handler = (_) => '{"docs": "não é uma lista"}';
      await expectLater(
        remote.search('x', page: 1),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.invalidResponse)),
      );
    });
  });
}
