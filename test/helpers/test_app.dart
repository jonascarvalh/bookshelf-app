import 'dart:typed_data';

import 'package:book_app/app/app.dart';
import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/core/network/dio_factory.dart';
import 'package:book_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_open_library.dart';
import 'fakes.dart';

/// Infraestrutura simulada usada pelos testes de widget e de integração.
class TestEnv {
  TestEnv(this.api, this.connectivity, this.database);

  final FakeHttpAdapter api;
  final FakeConnectivity connectivity;
  final AppDatabase database;
}

/// Registra o app com API simulada, banco em memória e conexão controlada.
Future<TestEnv> setUpTestApp({
  FakeHandler handler = openLibraryHandler,
  bool online = true,
  Map<int, Uint8List> covers = const {},
}) async {
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  SharedPreferences.setMockInitialValues({});
  // Um teste que falhou pode ter deixado o banco aberto; não tenta fechá-lo
  // aqui, fora da zona daquele teste.
  await sl.reset(dispose: false);

  final env = TestEnv(FakeHttpAdapter(handler), FakeConnectivity(online: online), memoryDatabase());
  await initDependencies(
    dio: DioFactory.create(adapter: env.api, sleep: (_) async {}),
    database: env.database,
    connectivity: env.connectivity,
    coverCache: FakeCoverCache(covers),
    reminders: FakeReminderScheduler(),
    prefs: await SharedPreferences.getInstance(),
  );
  return env;
}

extension AppTester on WidgetTester {
  Future<void> pumpApp({String location = '/shelf'}) async {
    await pumpWidget(EstanteApp(initialLocation: location));
    await pumpAndSettle();
  }

  /// Desmonta o app e fecha o banco, para não sobrar timer do drift.
  Future<void> disposeApp() async {
    await pumpWidget(const SizedBox());
    await pump(const Duration(seconds: 1));
    await runAsync(() => sl<AppDatabase>().close());
  }

  Future<void> searchFor(String text) async {
    await enterText(find.byKey(const Key('search_field')), text);
    await pump(const Duration(milliseconds: 500)); // debounce
    await pumpAndSettle();
  }
}
