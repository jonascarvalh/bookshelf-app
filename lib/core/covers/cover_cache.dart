import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum CoverSize {
  small('S'),
  medium('M'),
  large('L');

  const CoverSize(this.code);

  final String code;
}

/// Capas da Open Library guardadas em disco, para aparecerem offline.
abstract interface class CoverCache {
  /// Retorna os bytes da capa ou `null` se ela não existir ou não puder ser
  /// baixada agora.
  Future<Uint8List?> load(int coverId, {CoverSize size = CoverSize.medium});
}

class FileCoverCache implements CoverCache {
  FileCoverCache(this._dio, {Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  static const _memoryLimit = 80;

  final Dio _dio;
  final Future<Directory> Function() _directory;
  final _memory = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List?>>{};
  Directory? _dir;

  static Future<Directory> _defaultDirectory() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'covers'));

  @override
  Future<Uint8List?> load(int coverId, {CoverSize size = CoverSize.medium}) {
    final key = '$coverId-${size.code}';
    final hit = _memory.remove(key);
    if (hit != null) return Future.value(_memory[key] = hit); // move para o fim (LRU)
    return _inFlight[key] ??= _fetch(key).whenComplete(() => _inFlight.remove(key));
  }

  Future<Uint8List?> _fetch(String key) async {
    try {
      final dir = _dir ??= await (await _directory()).create(recursive: true);
      final file = File(p.join(dir.path, '$key.jpg'));

      Uint8List bytes;
      if (file.existsSync()) {
        bytes = await file.readAsBytes();
      } else {
        // `default=false` faz a API responder 404 em vez de uma imagem vazia.
        final response = await _dio.get<List<int>>(
          'https://covers.openlibrary.org/b/id/$key.jpg',
          queryParameters: {'default': 'false'},
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data ?? const []);
        if (bytes.isEmpty) return null;
        await file.writeAsBytes(bytes, flush: true);
      }

      _memory[key] = bytes;
      if (_memory.length > _memoryLimit) _memory.remove(_memory.keys.first);
      return bytes;
    } on Object {
      return null;
    }
  }
}
