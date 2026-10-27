import 'package:book_app/core/presentation/widgets/state_views.dart';
import 'package:book_app/core/utils/formatters.dart';
import 'package:book_app/features/books/presentation/search/search_cubit.dart';
import 'package:book_app/features/books/presentation/search/search_state.dart';
import 'package:book_app/features/books/presentation/widgets/book_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static const suggestions = [
    'Machado de Assis',
    'Clarice Lispector',
    'Tolkien',
    'Agatha Christie',
    'Ficção científica',
  ];

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SearchCubit>().state.query);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Começa a buscar a próxima página antes de chegar ao fim.
    if (_scroll.position.extentAfter < 600) context.read<SearchCubit>().loadMore();
  }

  void _searchFor(String text) {
    _controller.text = text;
    FocusScope.of(context).unfocus();
    context.read<SearchCubit>().search(text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: [
          IconButton(
            tooltip: 'Escanear código de barras',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => context.push('/scan'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => TextField(
                key: const Key('search_field'),
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: cubit.queryChanged,
                onSubmitted: cubit.search,
                decoration: InputDecoration(
                  hintText: 'Título ou autor',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            cubit.clear();
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) => switch (state.status) {
                SearchStatus.idle => _Suggestions(onTap: _searchFor),
                SearchStatus.loading => ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  itemBuilder: (_, _) => const BookTileSkeleton(),
                ),
                SearchStatus.failure => MessageView.error(
                  message: state.failure!.message,
                  onRetry: cubit.retry,
                ),
                SearchStatus.empty => MessageView(
                  icon: Icons.menu_book_rounded,
                  title: 'Nenhum livro encontrado',
                  message: 'Não achamos nada para "${state.query}". Confira a grafia ou tente '
                      'pelo nome do autor.',
                ),
                SearchStatus.success => _Results(state: state, controller: _scroll),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.controller});

  final SearchState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<SearchCubit>();
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text(
                Formatters.plural(state.totalCount, 'resultado', 'resultados'),
                style: theme.textTheme.labelLarge?.copyWith(color: muted),
              ),
              const Spacer(),
              if (state.isStale)
                Chip(
                  key: const Key('stale_chip'),
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(
                    state.cachedAt == null
                        ? 'Resultados salvos'
                        : 'Salvo em ${Formatters.dayMonth(state.cachedAt!)}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.retry,
            child: ListView.builder(
              key: const Key('results_list'),
              controller: controller,
              itemCount: state.books.length + 1,
              itemBuilder: (context, index) {
                if (index == state.books.length) return _Footer(state: state);
                final book = state.books[index];
                return BookListTile(
                  key: ValueKey(book.id),
                  book: book,
                  onTap: () => context.push('/book/${book.id}', extra: book),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final Widget child;
    if (state.pageFailure != null) {
      child = Column(
        children: [
          Text(state.pageFailure!.message, style: TextStyle(color: muted)),
          TextButton(
            onPressed: context.read<SearchCubit>().retry,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    } else if (state.isLoadingMore || state.hasMore) {
      child = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else {
      child = Text('Fim dos resultados', style: TextStyle(color: muted));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: child),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('Descubra seu próximo livro', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Milhões de títulos da Open Library. Busque pelo título, pelo autor '
          'ou escaneie o código de barras de um livro que está na sua mão.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text('Sugestões', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in SearchPage.suggestions)
              ActionChip(label: Text(s), onPressed: () => onTap(s)),
          ],
        ),
        const SizedBox(height: 28),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.primary),
            ),
            title: const Text('Escanear um livro'),
            subtitle: const Text('Aponte a câmera para o ISBN na contracapa'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/scan'),
          ),
        ),
      ],
    );
  }
}
