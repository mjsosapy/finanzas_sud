import 'package:intl/intl.dart';

class DateFormatters {
  static final DateFormat _shortDateFormatter = DateFormat('dd/MM/yyyy', 'es_PY');
  static final DateFormat _longDateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'es_PY');
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'es_PY', 
    symbol: 'PYG ', 
    decimalDigits: 0
  );

  static String formatShortDate(DateTime date) {
    return _shortDateFormatter.format(date);
  }

  static String formatLongDate(DateTime date) {
    return _longDateFormatter.format(date);
  }

  static String formatCurrency(double amount) {
    return _currencyFormatter.format(amount);
  }

  static DateTime? parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      print('Error parsing date: $dateString - $e');
      return null;
    }
  }
}