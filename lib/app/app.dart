import 'package:book_app/app/router.dart';
import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/core/presentation/connectivity_cubit.dart';
import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:book_app/features/books/presentation/search/search_cubit.dart';
import 'package:book_app/features/goals/presentation/goal_cubit.dart';
import 'package:book_app/features/shelf/domain/repositories/shelf_repository.dart';
import 'package:book_app/features/shelf/presentation/shelf_cubit.dart';
import 'package:book_app/features/stats/presentation/stats_cubit.dart';
import 'package:book_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class EstanteApp extends StatefulWidget {
  const EstanteApp({this.initialLocation = '/shelf', this.themeMode = ThemeMode.system, super.key});

  final String initialLocation;
  final ThemeMode themeMode;

  @override
  State<EstanteApp> createState() => _EstanteAppState();
}

class _EstanteAppState extends State<EstanteApp> {
  late final GoRouter _router = createRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BookRepository>.value(value: sl()),
        RepositoryProvider<ShelfRepository>.value(value: sl()),
        RepositoryProvider<CoverCache>.value(value: sl()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ConnectivityCubit(sl())),
          BlocProvider(create: (_) => SearchCubit(sl())),
          BlocProvider(create: (_) => ShelfCubit(sl())),
          BlocProvider(create: (_) => StatsCubit(sl())),
          BlocProvider(create: (_) => GoalCubit(sl(), sl())),
        ],
        child: MaterialApp.router(
          title: 'Estante',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: widget.themeMode,
          routerConfig: _router,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
  }
}
