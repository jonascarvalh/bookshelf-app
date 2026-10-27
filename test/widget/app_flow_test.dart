import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_open_library.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('busca mostra resultados com rolagem infinita', (tester) async {
    final env = await setUpTestApp();
    await tester.pumpApp(location: '/search');

    expect(find.text('Descubra seu próximo livro'), findsOneWidget);
    await tester.searchFor('machado de assis');

    expect(find.text('Dom Casmurro'), findsWidgets); // título na lista e na capa gerada
    expect(find.text('1.406 resultados'), findsOneWidget);

    await tester.fling(find.byKey(const Key('results_list')), const Offset(0, -3000), 3000);
    // O rodapé gira enquanto houver mais páginas, então não dá para usar
    // pumpAndSettle aqui.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.fling(find.byKey(const Key('results_list')), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();

    expect(find.text('Angústia'), findsWidgets); // livro da página 2
    expect(find.text('Fim dos resultados'), findsOneWidget);

    expect(env.api.requests.map((r) => r.queryParameters['page']), [1, 2, 3]);
    await tester.disposeApp();
  });

  testWidgets('sem resultados mostra estado vazio', (tester) async {
    await setUpTestApp();
    await tester.pumpApp(location: '/search');

    await tester.searchFor('livro que não existe');

    expect(find.text('Nenhum livro encontrado'), findsOneWidget);
    await tester.disposeApp();
  });

  testWidgets('erro de rede sem cache mostra erro e permite tentar de novo', (tester) async {
    final env = await setUpTestApp(handler: (o) => throw receiveTimeout(o));
    await tester.pumpApp(location: '/search');

    await tester.searchFor('machado');
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.textContaining('demorou para responder'), findsOneWidget);

    env.api.handler = openLibraryHandler;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Dom Casmurro'), findsWidgets); // título na lista e na capa gerada
    await tester.disposeApp();
  });

  testWidgets('offline: avisa e mostra a busca salva', (tester) async {
    final env = await setUpTestApp();
    await tester.pumpApp(location: '/search');
    await tester.searchFor('machado de assis');

    env.connectivity.online = false;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline_banner')), findsOneWidget);

    // Força uma nova busca da mesma consulta, agora sem internet.
    await tester.tap(find.byTooltip('Limpar'));
    await tester.pumpAndSettle();
    await tester.searchFor('machado de assis');

    expect(find.text('Dom Casmurro'), findsWidgets); // título na lista e na capa gerada
    await tester.disposeApp();
  });

  testWidgets('adicionar à estante aparece na aba Estante', (tester) async {
    await setUpTestApp();
    await tester.pumpApp(location: '/search');
    await tester.searchFor('machado de assis');

    await tester.tap(find.text('Dom Casmurro').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bento Gonçalves'), findsOneWidget); // sinopse da API

    await tester.tap(find.text('Quero ler'));
    await tester.pumpAndSettle();
    expect(find.text('Na sua estante'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quero ler · 1'));
    await tester.pumpAndSettle();

    expect(find.text('Dom Casmurro'), findsWidgets); // título na lista e na capa gerada
    await tester.disposeApp();
  });

  testWidgets('deep link por ISBN abre a página do livro', (tester) async {
    await setUpTestApp();
    await tester.pumpApp(location: '/isbn/9788500507007');

    expect(find.text('Dom Casmurro'), findsWidgets); // título na lista e na capa gerada
    expect(find.text('Adicionar à estante'), findsOneWidget);
    await tester.disposeApp();
  });

  testWidgets('ISBN desconhecido explica e sugere a busca', (tester) async {
    await setUpTestApp();
    await tester.pumpApp(location: '/isbn/9780000000002');

    expect(find.text('Livro não encontrado'), findsOneWidget);
    expect(find.text('Buscar pelo título'), findsOneWidget);
    await tester.disposeApp();
  });
}
