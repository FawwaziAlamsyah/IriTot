import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

/// Reads and writes CSV files on the user's device (web, Android, iOS).
class FileIoService {
  /// Opens the native file picker and returns the CSV text, or null if cancelled.
  static Future<String?> pickCsvText() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return decodeCsvBytes(bytes);
  }

  /// Decodes UTF-8 bytes and strips the BOM that Excel adds to CSV files.
  static String decodeCsvBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }

  /// Saves [csv] as a `.csv` file. On web this triggers a browser download.
  static Future<void> saveCsv({required String baseName, required String csv}) async {
    // BOM so Excel opens UTF-8 characters correctly.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  /// Builds a file name like `iritot_transactions_2026-10-23`.
  static String datedName(String prefix, [DateTime? now]) {
    final d = now ?? DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${prefix}_${d.year}-$mm-$dd';
  }
}
