import 'package:book_app/features/shelf/domain/entities/shelf_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ProgressInput = ({int page, int? totalPages});

/// Pergunta em que página o usuário está (e o total, se a API não informou).
Future<ProgressInput?> showProgressDialog(BuildContext context, ShelfEntry entry) {
  return showDialog<ProgressInput>(
    context: context,
    builder: (_) => _ProgressDialog(entry: entry),
  );
}

class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.entry});

  final ShelfEntry entry;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _page = TextEditingController(text: '${widget.entry.currentPage}');
  late final _total = TextEditingController(text: widget.entry.pages?.toString() ?? '');

  @override
  void dispose() {
    _page.dispose();
    _total.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((page: int.parse(_page.text), totalPages: int.tryParse(_total.text)));
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Em que página você está?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('page_field'),
              controller: _page,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(labelText: 'Página atual'),
              validator: (value) {
                final page = int.tryParse(value ?? '');
                if (page == null) return 'Informe a página';
                final total = int.tryParse(_total.text);
                if (total != null && page > total) return 'O livro tem $total páginas';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _total,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(labelText: 'Total de páginas'),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                return (int.tryParse(value) ?? 0) > 0 ? null : 'Total inválido';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
