/// Validação de ISBN-10 e ISBN-13 (EAN 978/979), com dígito verificador.
abstract final class Isbn {
  /// Remove hífens e espaços e retorna o ISBN se ele for válido.
  static String? parse(String raw) {
    final code = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (RegExp(r'^97[89]\d{10}$').hasMatch(code) && _validIsbn13(code)) return code;
    if (RegExp(r'^\d{9}[\dX]$').hasMatch(code) && _validIsbn10(code)) return code;
    return null;
  }

  static bool _validIsbn13(String code) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += int.parse(code[i]) * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }

  static bool _validIsbn10(String code) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final digit = code[i] == 'X' ? 10 : int.parse(code[i]);
      sum += digit * (10 - i);
    }
    return sum % 11 == 0;
  }
}
