import 'package:book_app/core/network/dio_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_open_library.dart';

void main() {
  late List<Duration> waits;

  Dio dioWith(FakeHandler handler) {
    waits = [];
    return DioFactory.create(
      adapter: FakeHttpAdapter(handler),
      sleep: (d) async => waits.add(d),
    );
  }

  test('repete após falha de conexão e devolve a resposta que deu certo', () async {
    var calls = 0;
    final dio = dioWith((o) {
      calls++;
      if (calls < 3) throw connectionError(o);
      return '{"ok": true}';
    });

    final response = await dio.get<Map<String, dynamic>>('/search.json');

    expect(response.data, {'ok': true});
    expect(calls, 3);
    expect(waits, const [Duration(milliseconds: 600), Duration(milliseconds: 1200)]);
  });

  test('repete erros 5xx e 429', () async {
    var calls = 0;
    final dio = dioWith((o) {
      calls++;
      return calls == 1 ? const FakeResponse('{}', 503) : const FakeResponse('{}', 200);
    });

    await dio.get<Map<String, dynamic>>('/x');
    expect(calls, 2);
  });

  test('não repete 404, porque a resposta seria a mesma', () async {
    var calls = 0;
    final dio = dioWith((o) {
      calls++;
      return const FakeResponse('{}', 404);
    });

    await expectLater(dio.get<Object>('/x'), throwsA(isA<DioException>()));
    expect(calls, 1);
    expect(waits, isEmpty);
  });

  test('desiste depois do limite de tentativas', () async {
    var calls = 0;
    final dio = dioWith((o) {
      calls++;
      throw receiveTimeout(o);
    });

    await expectLater(
      dio.get<Object>('/x'),
      throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.receiveTimeout)),
    );
    expect(calls, 3); // 1 tentativa + 2 repetições
  });
}
