import 'package:book_app/app/home_shell.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/presentation/details/book_details_cubit.dart';
import 'package:book_app/features/books/presentation/details/book_details_page.dart';
import 'package:book_app/features/books/presentation/search/search_page.dart';
import 'package:book_app/features/goals/presentation/goal_page.dart';
import 'package:book_app/features/scanner/presentation/isbn_lookup_page.dart';
import 'package:book_app/features/scanner/presentation/scanner_page.dart';
import 'package:book_app/features/shelf/presentation/shelf_page.dart';
import 'package:book_app/features/stats/presentation/stats_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Rotas do app.
///
/// As três abas ficam num [StatefulShellRoute], que preserva a rolagem e o
/// estado de cada uma. `/isbn/:isbn` também é o destino do deep link
/// `estante://app/isbn/9788535914849`.
GoRouter createRouter({String initialLocation = '/shelf'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/shelf', builder: (_, _) => const ShelfPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/search', builder: (_, _) => const SearchPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/stats', builder: (_, _) => const StatsPage())],
          ),
        ],
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initial = state.extra is Book ? state.extra! as Book : null;
          return BlocProvider(
            create: (context) => BookDetailsCubit(
              bookId: id,
              initial: initial,
              books: context.read(),
              shelf: context.read(),
            ),
            child: const BookDetailsPage(),
          );
        },
      ),
      GoRoute(
        path: '/isbn/:isbn',
        builder: (_, state) => IsbnLookupPage(isbn: state.pathParameters['isbn']!),
      ),
      GoRoute(path: '/scan', builder: (_, _) => const ScannerPage()),
      GoRoute(path: '/goal', builder: (_, _) => const GoalPage()),
    ],
  );
}
