import 'dart:io';

import 'package:book_app/features/scanner/domain/isbn.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Leitor de código de barras: ao reconhecer um ISBN, abre o livro.
class ScannerPage extends StatefulWidget {
  const ScannerPage({this.cameraPreview, super.key});

  /// Substitui a câmera (testes e plataformas sem câmera).
  final Widget? cameraPreview;

  static bool get cameraSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController? _controller;
  bool _handled = false;

  bool get _useCamera => widget.cameraPreview == null && ScannerPage.cameraSupported;

  @override
  void initState() {
    super.initState();
    if (_useCamera) {
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.ean13],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final isbn = Isbn.parse(barcode.rawValue ?? '');
      if (isbn != null) {
        _open(isbn);
        return;
      }
    }
  }

  void _open(String isbn) {
    _handled = true;
    context.pushReplacement('/isbn/$isbn');
  }

  Future<void> _typeIsbn() async {
    final isbn = await showDialog<String>(context: context, builder: (_) => const _IsbnDialog());
    if (isbn != null && mounted) _open(isbn);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Escanear livro'),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: 'Lanterna',
              icon: const Icon(Icons.flashlight_on_rounded),
              onPressed: controller.toggleTorch,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraMessage(
                text: switch (error.errorCode) {
                  MobileScannerErrorCode.permissionDenied =>
                    'O Estante precisa da câmera para ler o código de barras. '
                        'Libere o acesso nas configurações ou digite o ISBN.',
                  _ => 'Não foi possível abrir a câmera. Digite o ISBN abaixo.',
                },
              ),
            )
          else
            widget.cameraPreview ??
                const _CameraMessage(
                  text: 'A câmera não está disponível neste dispositivo. Digite o ISBN abaixo.',
                ),
          const _Viewfinder(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: SafeArea(
              child: Column(
                children: [
                  const Text(
                    'Aponte para o código de barras na contracapa',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'O ISBN começa com 978 ou 979',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('type_isbn_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _typeIsbn,
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Digitar ISBN'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Moldura com cantos destacados sobre a imagem da câmera.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.78;
        final rect = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero).translate(0, -40),
          width: width,
          height: width * 0.55,
        );
        return CustomPaint(
          size: constraints.biggest,
          // Cor fixa: a moldura fica sobre a imagem da câmera, não sobre o tema.
          painter: _ViewfinderPainter(rect, const Color(0xFFE8B86A)),
        );
      },
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.rect, this.accent);

  final Rect rect;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(frame),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final corner = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    final r = rect;
    for (final (p, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(p.translate(dx * 6, dy * 6), p.translate(dx * len, dy * 6), corner)
        ..drawLine(p.translate(dx * 6, dy * 6), p.translate(dx * 6, dy * len), corner);
    }
    canvas.drawLine(
      Offset(r.left + 24, r.center.dy),
      Offset(r.right - 24, r.center.dy),
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.8)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.rect != rect || old.accent != accent;
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111111),
      child: Align(
        alignment: const Alignment(0, -0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 100, 32, 0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _IsbnDialog extends StatefulWidget {
  const _IsbnDialog();

  @override
  State<_IsbnDialog> createState() => _IsbnDialogState();
}

class _IsbnDialogState extends State<_IsbnDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final isbn = Isbn.parse(_controller.text);
    if (isbn == null) {
      setState(() => _error = 'ISBN inválido. Confira os 10 ou 13 dígitos.');
      return;
    }
    Navigator.of(context).pop(isbn);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Digitar ISBN'),
      content: TextField(
        key: const Key('isbn_field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: '978…', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Buscar')),
      ],
    );
  }
}
