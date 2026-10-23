import 'file_io_stub.dart'
    if (dart.library.js_interop) 'file_io_web.dart'
    if (dart.library.io) 'file_io_io.dart' as impl;

/// Reads and writes CSV files on the user's device across Web, Android, iOS, and Desktop.
class FileIoService {
  /// Opens the native file picker and returns the CSV text, or null if cancelled.
  static Future<String?> pickCsvText() => impl.pickCsvImpl();

  /// Saves [csv] as a `.csv` file. On web this triggers a direct browser download.
  static Future<void> saveCsv({required String baseName, required String csv}) =>
      impl.saveCsvImpl(baseName: baseName, csv: csv);

  /// Builds a dated file name like `iritot_transactions_2026-10-23`.
  static String datedName(String prefix, [DateTime? now]) {
    final d = now ?? DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${prefix}_${d.year}-$mm-$dd';
  }
}
