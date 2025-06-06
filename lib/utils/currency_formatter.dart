import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final String locale;
  final String currencySymbol;
  final int decimalDigits;

  CurrencyInputFormatter({
    this.locale = 'en_US',
    this.currencySymbol = '',
    this.decimalDigits = 0, 
  });

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) {
      return TextEditingValue.empty;
    }
    
    double value = double.parse(cleanText);
        
    // Usar formato simple sin símbolos de moneda
    final formatter = NumberFormat('#,##0');
    
    String newFormattedText = formatter.format(value);

    int selectionIndex = newValue.selection.end + (newFormattedText.length - newValue.text.length);
    if (selectionIndex > newFormattedText.length) {
      selectionIndex = newFormattedText.length;
    }
    if (selectionIndex < 0) {
      selectionIndex = 0;
    }

    return TextEditingValue(
      text: newFormattedText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class CurrencyUtils {
  static String formatCurrency(double amount) {
    String numberStr = amount.toInt().toString();
    String formatted = '';
    int counter = 0;
    
    for (int i = numberStr.length - 1; i >= 0; i--) {
      if (counter == 3) {
        formatted = ',$formatted';
        counter = 0;
      }
      formatted = numberStr[i] + formatted;
      counter++;
    }
    
    return '$formatted Gs.';
  }

  static String formatAmountWithDots(int amount) {
    String numberStr = amount.toString();
    String formatted = '';
    int counter = 0;
    
    for (int i = numberStr.length - 1; i >= 0; i--) {
      if (counter == 3) {
        formatted = '.$formatted';
        counter = 0;
      }
      formatted = numberStr[i] + formatted;
      counter++;
    }
    
    return formatted;
  }
}