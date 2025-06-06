class NumberToWordsHelper {
  static const List<String> _unidades = [
    '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'
  ];

  static const List<String> _decenas = [
    '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'
  ];

  static const List<String> _centenas = [
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 
    'seiscientos', 'setecientos', 'ochocientos', 'novecientos'
  ];

  static const List<String> _especiales = [
    'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve'
  ];

  static const List<String> _veintes = [
    'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 
    'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve'
  ];

  static String convertToWords(double amount) {
    if (amount == 0) return 'cero guaraníes';
    
    int intAmount = amount.toInt();
    return '${_convertNumber(intAmount)} guaraníes';
  }

  static String _convertNumber(int number) {
    if (number == 0) return 'cero';
    if (number < 0) return 'menos ${_convertNumber(-number)}';

    String result = '';

    // Millones
    if (number >= 1000000) {
      int millones = number ~/ 1000000;
      if (millones == 1) {
        result += 'un millón ';
      } else {
        result += '${_convertNumber(millones)} millones ';
      }
      number %= 1000000;
    }

    // Miles
    if (number >= 1000) {
      int miles = number ~/ 1000;
      if (miles == 1) {
        result += 'mil ';
      } else {
        result += '${_convertNumber(miles)} mil ';
      }
      number %= 1000;
    }

    // Centenas, decenas y unidades
    if (number > 0) {
      result += _convertHundreds(number);
    }

    return result.trim();
  }

  static String _convertHundreds(int number) {
    String result = '';

    // Centenas
    if (number >= 100) {
      int centenas = number ~/ 100;
      if (number == 100) {
        result += 'cien';
        return result;
      } else {
        result += '${_centenas[centenas]} ';
      }
      number %= 100;
    }

    // Decenas y unidades
    if (number >= 30) {
      int decenas = number ~/ 10;
      int unidades = number % 10;
      result += _decenas[decenas];
      if (unidades > 0) {
        result += ' y ${_unidades[unidades]}';
      }
    } else if (number >= 20) {
      result += _veintes[number - 20];
    } else if (number >= 10) {
      result += _especiales[number - 10];
    } else if (number > 0) {
      result += _unidades[number];
    }

    return result;
  }
}