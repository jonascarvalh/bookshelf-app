import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/database/app_database.dart';
import 'package:book_app/core/network/connectivity_service.dart';
import 'package:book_app/core/network/dio_factory.dart';
import 'package:book_app/core/notifications/reminder_scheduler.dart';
import 'package:book_app/features/books/data/datasources/book_local_data_source.dart';
import 'package:book_app/features/books/data/datasources/book_remote_data_source.dart';
import 'package:book_app/features/books/data/repositories/book_repository_impl.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/features/goals/data/goal_repository.dart';
import 'package:book_app/features/shelf/data/repositories/shelf_repository_impl.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service locator da aplicação.
final sl = GetIt.instance;

/// Registra as dependências, de fora (infraestrutura) para dentro.
///
/// Os parâmetros permitem trocar a infraestrutura nos testes de integração e
/// nas capturas de tela: API simulada, banco em memória, conexão controlada.
Future<void> initDependencies({
  Dio? dio,
  AppDatabase? database,
  ConnectivityService? connectivity,
  CoverCache? coverCache,
  ReminderScheduler? reminders,
  SharedPreferences? prefs,
}) async {
  await sl.reset();
  final api = dio ?? DioFactory.create();

  sl
    // ── Externos ────────────────────────────────────────────────────────────
    ..registerSingleton<Dio>(api)
    ..registerSingleton<AppDatabase>(database ?? AppDatabase.open(), dispose: (db) => db.close())
    ..registerSingleton<SharedPreferences>(prefs ?? await SharedPreferences.getInstance())
    ..registerSingleton<ConnectivityService>(connectivity ?? ConnectivityPlusService())
    ..registerSingleton<CoverCache>(coverCache ?? FileCoverCache(DioFactory.create()))
    ..registerSingleton<ReminderScheduler>(reminders ?? LocalNotificationsReminderScheduler())

    // ── Data sources ──────────────────────────────────────────────────────
    ..registerLazySingleton<BookRemoteDataSource>(() => OpenLibraryRemoteDataSource(sl()))
    ..registerLazySingleton<BookLocalDataSource>(() => DriftBookLocalDataSource(sl()))

    // ── Repositórios ──────────────────────────────────────────────────────
    ..registerLazySingleton<BookRepository>(
      () => BookRepositoryImpl(remote: sl(), local: sl(), connectivity: sl()),
    )
    ..registerLazySingleton<ShelfRepository>(() => ShelfRepositoryImpl(sl()))
    ..registerLazySingleton<GoalRepository>(() => PrefsGoalRepository(sl()));
}
