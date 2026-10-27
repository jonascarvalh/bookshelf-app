import 'dart:async';

import 'package:book_app/app/app.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await initDependencies();

  // Limpeza do cache em segundo plano; não atrasa a abertura do app.
  unawaited(sl<BookRepository>().evictStaleCache());

  runApp(const EstanteApp());
}
