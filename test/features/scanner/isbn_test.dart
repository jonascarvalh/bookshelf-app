import 'package:book_app/features/scanner/domain/isbn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita ISBN-13 válido, com ou sem hífens', () {
    expect(Isbn.parse('9788500507007'), '9788500507007');
    expect(Isbn.parse('978-85-00-50700-7'), '9788500507007');
    expect(Isbn.parse(' 978 0 14 044836 8 '), '9780140448368');
  });

  test('aceita ISBN-10, inclusive com X no dígito verificador', () {
    expect(Isbn.parse('0-14-044836-0'), isNull); // dígito errado
    expect(Isbn.parse('0140448365'), '0140448365');
    expect(Isbn.parse('080442957x'), '080442957X');
  });

  test('recusa códigos que não são ISBN', () {
    expect(Isbn.parse('9788500507008'), isNull, reason: 'dígito verificador errado');
    expect(Isbn.parse('7891000100103'), isNull, reason: 'EAN de produto, não de livro');
    expect(Isbn.parse('123'), isNull);
    expect(Isbn.parse(''), isNull);
  });
}
