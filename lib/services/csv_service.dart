import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/savings_pocket.dart';
import '../models/savings_record.dart';

class ParsedSavingsCsv {
  final List<SavingsPocket> pockets;
  final List<SavingsRecord> records;

  const ParsedSavingsCsv({
    required this.pockets,
    required this.records,
  });
}

class CsvService {
  static bool isSavingsCsv(String csvString) {
    final trimmed = csvString.trim();
    if (trimmed.isEmpty) return false;
    final firstLine = trimmed.split(RegExp(r'\r?\n')).first.toLowerCase();
    return firstLine.contains('kantong') ||
        firstLine.contains('pocket') ||
        firstLine.contains('saldo_akhir') ||
        firstLine.contains('saldo akhir');
  }

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

  static String exportSavingsToCsv({
    required List<SavingsPocket> pockets,
    required List<SavingsRecord> records,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer();
    buffer.writeln('ID,Tanggal,Kantong,Tipe,Nominal,Catatan,Saldo_Akhir');

    final sorted = List<SavingsRecord>.from(records)..sort((a, b) => a.date.compareTo(b.date));
    final runningBalances = <String, double>{};

    for (final r in sorted) {
      final prev = runningBalances[r.pocketName] ?? 0.0;
      final current = r.isIn ? prev + r.amount : prev - r.amount;
      runningBalances[r.pocketName] = current;

      final id = _escapeCsv(r.id);
      final dateStr = dateFormat.format(r.date);
      final pocketName = _escapeCsv(r.pocketName);
      final type = r.type;
      final nominal = r.amount.toStringAsFixed(0);
      final note = _escapeCsv(r.note);
      final bal = current.toStringAsFixed(0);

      buffer.writeln('$id,$dateStr,$pocketName,$type,$nominal,$note,$bal');
    }

    return buffer.toString();
  }

  static ParsedSavingsCsv parseCsvToSavings(String csvString) {
    final lines = csvString.split(RegExp(r'\r?\n'));
    if (lines.length <= 1) return const ParsedSavingsCsv(pockets: [], records: []);

    String delimiter = ',';
    if (lines.isNotEmpty && lines[0].contains(';') && !lines[0].contains(',')) {
      delimiter = ';';
    }

    final headerCols = _splitCsvLine(lines[0], delimiter).map((c) => c.trim().toLowerCase()).toList();
    final colMap = <String, int>{};
    for (int idx = 0; idx < headerCols.length; idx++) {
      colMap[headerCols[idx]] = idx;
    }

    int idCol = colMap['id'] ?? 0;
    int dateCol = colMap['tanggal'] ?? colMap['date'] ?? 1;
    int pocketCol = colMap['kantong'] ?? colMap['pocket'] ?? 2;
    int typeCol = colMap['tipe'] ?? colMap['type'] ?? 3;
    int amountCol = colMap['nominal'] ?? colMap['amount'] ?? 4;
    int noteCol = colMap['catatan'] ?? colMap['note'] ?? colMap['keterangan'] ?? 5;
    int balanceCol = colMap['saldo_akhir'] ?? colMap['saldo akhir'] ?? colMap['balance'] ?? 6;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final Map<String, double> latestBalances = {};
    final Map<String, double> calculatedBalances = {};
    final Map<String, DateTime> pocketCreatedDates = {};
    final List<SavingsRecord> records = [];

    const pocketColors = [
      0xFF38BDF8, // Sky Blue
      0xFF10B981, // Emerald Green
      0xFFF59E0B, // Amber
      0xFF8B5CF6, // Purple
      0xFF14B8A6, // Teal
      0xFF6366F1, // Indigo
      0xFFEC4899, // Pink
      0xFFF97316, // Orange
      0xFF06B6D4, // Cyan
    ];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line, delimiter);
      if (cols.length < 5) continue;

      try {
        final id = (idCol < cols.length && cols[idCol].trim().isNotEmpty)
            ? cols[idCol].trim()
            : 'sav_rec_${DateTime.now().microsecondsSinceEpoch}_$i';

        DateTime date;
        try {
          date = dateFormat.parse(cols[dateCol].trim());
        } catch (_) {
          date = DateTime.tryParse(cols[dateCol].trim()) ?? DateTime.now();
        }

        final rawPocketName = cols.length > pocketCol ? cols[pocketCol].trim() : 'Tabungan';
        final pocketName = rawPocketName.isEmpty ? 'Tabungan' : rawPocketName;
        final type = (cols.length > typeCol ? cols[typeCol].trim().toLowerCase() : 'in') == 'out' ? 'out' : 'in';
        final amount = cols.length > amountCol ? (double.tryParse(cols[amountCol].trim()) ?? 0.0) : 0.0;
        final note = cols.length > noteCol ? cols[noteCol].trim() : '';

        double? reportedBalance;
        if (cols.length > balanceCol && cols[balanceCol].trim().isNotEmpty) {
          reportedBalance = double.tryParse(cols[balanceCol].trim());
        }

        final pocketId = 'pocket_${pocketName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

        records.add(SavingsRecord(
          id: id,
          pocketId: pocketId,
          pocketName: pocketName,
          walletId: 'w_cash',
          walletName: 'Dompet Utama',
          type: type,
          amount: amount,
          note: note,
          date: date,
        ));

        if (!calculatedBalances.containsKey(pocketName)) {
          calculatedBalances[pocketName] = 0.0;
          pocketCreatedDates[pocketName] = date;
        }
        if (type == 'in') {
          calculatedBalances[pocketName] = calculatedBalances[pocketName]! + amount;
        } else {
          calculatedBalances[pocketName] = calculatedBalances[pocketName]! - amount;
        }

        if (reportedBalance != null) {
          latestBalances[pocketName] = reportedBalance;
        }
      } catch (_) {}
    }

    final List<SavingsPocket> pockets = [];
    int colorIdx = 0;
    for (final entry in calculatedBalances.entries) {
      final pName = entry.key;
      final finalAmount = latestBalances[pName] ?? entry.value;
      final pocketId = 'pocket_${pName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final color = pocketColors[colorIdx % pocketColors.length];
      colorIdx++;

      pockets.add(SavingsPocket(
        id: pocketId,
        name: pName,
        targetAmount: 0.0,
        currentAmount: finalAmount < 0 ? 0 : finalAmount,
        colorValue: color,
        icon: 'savings',
        createdAt: pocketCreatedDates[pName] ?? DateTime.now(),
      ));
    }

    return ParsedSavingsCsv(pockets: pockets, records: records);
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
