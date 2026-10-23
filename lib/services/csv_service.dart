import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../models/category.dart';

class CsvService {
  static String exportTransactionsToCsv({
    required List<TransactionItem> transactions,
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
  }) {
    final walletMap = {for (var w in wallets) w.id: w.name};
    final catMap = {for (var c in categories) c.id: c.name};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final buffer = StringBuffer();
    // Header
    buffer.writeln('ID,Tanggal,Tipe,Dompet,Kategori,Nominal,Keterangan');

    for (final t in transactions) {
      final walletName = _escapeCsv(walletMap[t.walletId] ?? t.walletId);
      final catName = _escapeCsv(catMap[t.categoryId] ?? t.categoryId);
      final note = _escapeCsv(t.note);
      final dateStr = dateFormat.format(t.date);

      buffer.writeln('${t.id},$dateStr,${t.type},$walletName,$catName,${t.amount.toStringAsFixed(0)},$note');
    }

    return buffer.toString();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<TransactionItem> parseCsvToTransactions({
    required String csvString,
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
  }) {
    final lines = csvString.split(RegExp(r'\r?\n'));
    if (lines.length <= 1) return [];

    final walletMap = {for (var w in wallets) w.name.toLowerCase(): w.id};
    final catMap = {for (var c in categories) c.name.toLowerCase(): c.id};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Deteksi pemisah delimiter (koma atau titik koma)
    String delimiter = ',';
    if (lines.isNotEmpty && lines[0].contains(';') && !lines[0].contains(',')) {
      delimiter = ';';
    }

    List<TransactionItem> items = [];

    // Skip header line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line, delimiter);
      if (cols.length < 6) continue;

      try {
        final id = cols[0].trim().isNotEmpty
            ? cols[0].trim()
            : 'tx_imp_${DateTime.now().microsecondsSinceEpoch}_$i';

        DateTime date;
        try {
          date = dateFormat.parse(cols[1].trim());
        } catch (_) {
          date = DateTime.tryParse(cols[1].trim()) ?? DateTime.now();
        }

        final type = cols[2].trim().toLowerCase();
        final walletName = cols[3].trim().toLowerCase();
        final catName = cols[4].trim().toLowerCase();
        final amount = double.tryParse(cols[5].trim()) ?? 0.0;
        final note = cols.length > 6 ? cols[6].trim() : '';

        final walletId = walletMap[walletName] ?? (wallets.isNotEmpty ? wallets.first.id : 'w_cash');
        final categoryId = catMap[catName] ?? (categories.isNotEmpty ? categories.first.id : 'cat_food');

        items.add(TransactionItem(
          id: id,
          walletId: walletId,
          categoryId: categoryId,
          type: type,
          amount: amount,
          note: note,
          date: date,
        ));
      } catch (_) {
        // Abaikan baris rusak
      }
    }

    return items;
  }

  static List<String> _splitCsvLine(String line, [String delimiter = ',']) {
    List<String> result = [];
    StringBuffer cur = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++; // skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(cur.toString());
        cur.clear();
      } else {
        cur.write(char);
      }
    }
    result.add(cur.toString());
    return result;
  }
}
