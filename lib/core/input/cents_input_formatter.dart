import 'package:flutter/services.dart';

/// Money entry with a fixed two-digit fraction: 9 -> 0.09 -> 0.99 -> 9.90.
class CentsInputFormatter extends TextInputFormatter {
  const CentsInputFormatter();

  static final _nonDigits = RegExp(r'[^0-9]');
  static final _leadingZeros = RegExp(r'^0+');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == oldValue.text ||
        (newValue.composing.isValid && !newValue.composing.isCollapsed)) {
      return newValue;
    }

    final digits = newValue.text
        .replaceAll(_nonDigits, '')
        .replaceFirst(_leadingZeros, '');
    // Match the ledger's limit of ten whole-number digits and two cents digits.
    if (digits.length > 12) return oldValue;

    final padded = digits.padLeft(3, '0');
    final split = padded.length - 2;
    final text = '${padded.substring(0, split)}.${padded.substring(split)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
