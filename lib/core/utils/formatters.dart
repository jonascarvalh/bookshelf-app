import 'package:intl/intl.dart';

abstract final class Formatters {
  static final _number = NumberFormat.decimalPattern('pt_BR');
  static final _monthYear = DateFormat("MMM 'de' y", 'pt_BR');
  static final _dayMonth = DateFormat("d 'de' MMM", 'pt_BR');
  static final _monthShort = DateFormat('MMM', 'pt_BR');

  static String number(num value) => _number.format(value);

  static String monthYear(DateTime date) => _monthYear.format(date);

  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// `out`, `nov`… sem o ponto que o intl coloca em algumas abreviações.
  static String monthShort(DateTime date) => _monthShort.format(date).replaceAll('.', '');

  static String plural(int count, String singular, String plural) =>
      '${number(count)} ${count == 1 ? singular : plural}';
}
