import 'dart:typed_data';

import 'package:book_app/core/covers/cover_cache.dart';
import 'package:book_app/features/books/domain/entities/book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Capa do livro na proporção 2:3, com capa gerada quando não há imagem.
class BookCover extends StatefulWidget {
  const BookCover({
    required this.book,
    required this.width,
    this.size = CoverSize.medium,
    this.radius = 8,
    super.key,
  });

  final Book book;
  final double width;
  final CoverSize size;
  final double radius;

  @override
  State<BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<BookCover> {
  Future<Uint8List?>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bytes ??= _load();
  }

  @override
  void didUpdateWidget(BookCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.coverId != widget.book.coverId) _bytes = _load();
  }

  Future<Uint8List?>? _load() {
    final id = widget.book.coverId;
    return id == null ? null : context.read<CoverCache>().load(id, size: widget.size);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * 1.5;
    return Container(
      width: widget.width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) {
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _GeneratedCover(book: widget.book, width: widget.width),
            );
          }
          return _GeneratedCover(
            book: widget.book,
            width: widget.width,
            loading: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      ),
    );
  }
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.book, required this.width, this.loading = false});

  final Book book;
  final double width;
  final bool loading;

  static const _palette = [
    (Color(0xFF2E5E4E), Color(0xFF1F4036)),
    (Color(0xFF7A3E2E), Color(0xFF55291E)),
    (Color(0xFF34495E), Color(0xFF22303D)),
    (Color(0xFF8C6D1F), Color(0xFF5F4A14)),
    (Color(0xFF5B3F6B), Color(0xFF3D2A48)),
  ];

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = _palette[book.id.hashCode.abs() % _palette.length];
    final small = width < 70;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [top, bottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: AnimatedOpacity(
        opacity: loading ? 0.35 : 1,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: EdgeInsets.all(width * 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: width * 0.3, height: 2, color: Colors.white54),
              SizedBox(height: width * 0.08),
              Expanded(
                child: Text(
                  book.title,
                  maxLines: small ? 3 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (width * 0.13).clamp(8, 22),
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              if (!small)
                Text(
                  book.authorsLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: (width * 0.09).clamp(8, 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
