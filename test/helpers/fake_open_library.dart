import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Lê um JSON de `test/fixtures` (respostas reais da Open Library, reduzidas).
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

typedef FakeHandler = Object Function(RequestOptions options);

/// [HttpClientAdapter] que responde sem rede.
///
/// O handler devolve um `String` (corpo JSON com status 200), um
/// [FakeResponse] ou lança um [DioException] para simular falhas.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  FakeHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = handler(options);
    final response = result is FakeResponse ? result : FakeResponse(result as String);
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeResponse {
  const FakeResponse(this.body, [this.status = 200]);

  final String body;
  final int status;
}

/// Simula a Open Library a partir das fixtures, roteando pelo caminho e pelos
/// parâmetros da requisição.
Object openLibraryHandler(RequestOptions options) {
  final params = options.queryParameters;
  switch (options.path) {
    case '/search.json' when params.containsKey('isbn'):
      return params['isbn'] == '9788500507007'
          ? fixture('search_isbn.json')
          : jsonEncode({'numFound': 0, 'start': 0, 'docs': <Object>[]});
    case '/search.json':
      final query = '${params['q']}';
      if (!query.contains('machado')) return fixture('search_empty.json');
      return switch (params['page']) {
        1 => fixture('search_page1.json'),
        2 => fixture('search_page2.json'),
        _ => jsonEncode({'numFound': 1406, 'start': 40, 'docs': <Object>[]}),
      };
    case '/works/OL1003040W.json':
      return fixture('work.json');
    case final String path when path.startsWith('/works/'):
      return jsonEncode({'title': 'Obra'});
  }
  return const FakeResponse('{"error": "not found"}', 404);
}

DioException connectionError(RequestOptions options) =>
    DioException.connectionError(requestOptions: options, reason: 'sem rede (teste)');

DioException receiveTimeout(RequestOptions options) => DioException.receiveTimeout(
  timeout: const Duration(seconds: 12),
  requestOptions: options,
);
