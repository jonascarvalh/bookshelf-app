import 'package:book_app/core/error/failures.dart';
import 'package:book_app/core/presentation/widgets/state_views.dart';
import 'package:book_app/core/result/result.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:book_app/features/books/domain/repositories/book_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Resolve um ISBN (do scanner ou de um deep link `estante://app/isbn/...`)
/// e abre a página do livro.
class IsbnLookupPage extends StatefulWidget {
  const IsbnLookupPage({required this.isbn, super.key});

  final String isbn;

  @override
  State<IsbnLookupPage> createState() => _IsbnLookupPageState();
}

class _IsbnLookupPageState extends State<IsbnLookupPage> {
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    setState(() => _failure = null);
    final result = await context.read<BookRepository>().findByIsbn(widget.isbn);
    if (!mounted) return;
    switch (result) {
      case Ok<Book>(value: final book):
        context.pushReplacement('/book/${book.id}', extra: book);
      case Err<Book>(:final failure):
        setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return Scaffold(
      appBar: AppBar(title: Text('ISBN ${widget.isbn}')),
      body: failure == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Procurando o livro…'),
                ],
              ),
            )
          : switch (failure) {
              NotFoundFailure() => MessageView(
                icon: Icons.search_off_rounded,
                title: 'Livro não encontrado',
                message: '${failure.message} Tente buscar pelo título.',
                actionLabel: 'Buscar pelo título',
                onAction: () => context.go('/search'),
              ),
              _ => MessageView.error(message: failure.message, onRetry: _lookup),
            },
    );
  }
}
