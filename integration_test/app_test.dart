import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_open_library.dart';
import '../test/helpers/test_app.dart';

/// Fluxo principal no app de verdade (Android ou desktop), com a Open Library
/// simulada: buscar → abrir → começar a ler → registrar progresso → ver na
/// estante e nas estatísticas → continuar funcionando offline.
///
/// `flutter test integration_test -d linux` (ou `-d <id do Android>`)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('da busca à estatística, e depois offline', (tester) async {
    final env = await setUpTestApp(handler: _api);
    await tester.pumpApp();

    // Estante vazia na primeira abertura.
    expect(find.text('Nenhuma leitura em andamento'), findsOneWidget);

    // Buscar
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    await tester.searchFor('machado de assis');
    expect(find.text('O Alienista'), findsWidgets);

    // Abrir o livro: a sinopse vem da API de obras.
    await tester.tap(find.text('Dom Casmurro').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bento Gonçalves'), findsOneWidget);

    // Começar a ler e registrar o progresso.
    await tester.tap(find.text('Lendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update_progress_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('page_field')), '134');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Página 134 de 268'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // Na estante, na aba "Lendo".
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estante'));
    await tester.pumpAndSettle();
    expect(find.text('Lendo · 1'), findsOneWidget);
    expect(find.text('Página 134 de 268 · 50%'), findsOneWidget);

    // As páginas entram nas estatísticas do mês.
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();
    expect(find.text('134'), findsWidgets);
    expect(find.text('0 de 12 livros'), findsOneWidget);

    // Offline: aviso na tela e busca respondida pelo cache.
    env.connectivity.online = false;
    env.api.handler = (o) => throw connectionError(o);
    await tester.tap(find.text('Buscar').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline_banner')), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar'));
    await tester.pumpAndSettle();
    await tester.searchFor('machado de assis');
    expect(find.text('O Alienista'), findsWidgets);
    expect(find.byKey(const Key('stale_chip')), findsNothing); // cache ainda recente

    await tester.disposeApp();
  });
}

/// API simulada com dados embutidos, para rodar também no aparelho (onde os
/// arquivos de `test/fixtures` não existem).
Object _api(RequestOptions options) {
  Map<String, Object?> doc(String id, String title, int pages, int year) => {
    'key': '/works/$id',
    'title': title,
    'author_name': ['Machado de Assis'],
    'number_of_pages_median': pages,
    'first_publish_year': year,
    'isbn': <String>[],
  };

  if (options.path == '/search.json') {
    final page = options.queryParameters['page'];
    return jsonEncode({
      'numFound': 3,
      'start': 0,
      'docs': page == 1
          ? [
              doc('OL1003040W', 'Dom Casmurro', 268, 1899),
              doc('OL1003017W', 'Memórias póstumas de Brás Cubas', 242, 1881),
              doc('OL1003134W', 'O Alienista', 100, 1882),
            ]
          : <Object>[],
    });
  }
  if (options.path == '/works/OL1003040W.json') {
    return jsonEncode({
      'title': 'Dom Casmurro',
      'description': 'O livro narra a história de Bento Gonçalves desde sua juventude.',
    });
  }
  return const FakeResponse('{}', 404);
}
