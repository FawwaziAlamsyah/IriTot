import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter otomatis untuk menambahkan titik pemisah ribuan saat mengetik angka.
/// Contoh: 1000 -> 1.000, 1000000 -> 1.000.000
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ambil hanya karakter angka
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }

    // Batasi maksimum 15 digit angka agar aman dari overflow
    final clampedDigits = cleanDigits.length > 15 ? cleanDigits.substring(0, 15) : cleanDigits;

    final number = int.tryParse(clampedDigits);
    if (number == null) {
      return oldValue;
    }

    // Format angka ke format ribuan Indonesia (menggunakan titik)
    final formatted = _formatter.format(number);

    // Hitung posisi kursor baru yang presisi berdasarkan jumlah digit sebelum kursor
    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    final int digitsBeforeCursor = newValue.text
        .substring(0, selectionEnd)
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    int newCursorOffset = formatted.length;
    if (selectionEnd < newValue.text.length) {
      int digitsSeen = 0;
      for (int i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) {
          digitsSeen++;
        }
        if (digitsSeen >= digitsBeforeCursor) {
          newCursorOffset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset.clamp(0, formatted.length)),
    );
  }

  /// Helper untuk memformat angka numerik ke string ribuan (contoh: 1000000 -> "1.000.000")
  static String format(num value) {
    if (value <= 0) return '';
    return _formatter.format(value.round());
  }

  /// Helper untuk membaca nilai double dari string ribuan bertitik
  static double parse(String text) {
    final clean = text.replaceAll('.', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }
}
