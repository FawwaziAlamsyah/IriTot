import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/category.dart';
import '../models/wallet.dart';

class AiService {
  static const String _keyAiProvider = 'iritot_ai_provider';
  static const String _keyApiKey = 'iritot_ai_api_key';
  static const String _keyCustomEndpoint = 'iritot_ai_custom_endpoint';

  final SharedPreferences _prefs;

  AiService(this._prefs);

  static Future<AiService> init([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    return AiService(prefs);
  }

  String getProvider() => _prefs.getString(_keyAiProvider) ?? 'gemini';
  Future<void> setProvider(String provider) => _prefs.setString(_keyAiProvider, provider);

  String getApiKey() => _prefs.getString(_keyApiKey) ?? '';
  Future<void> setApiKey(String key) => _prefs.setString(_keyApiKey, key.trim());

  String getCustomEndpoint() => _prefs.getString(_keyCustomEndpoint) ?? 'http://127.0.0.1:11434';
  Future<void> setCustomEndpoint(String endpoint) => _prefs.setString(_keyCustomEndpoint, endpoint.trim());

  bool get hasApiKey => getApiKey().isNotEmpty;

  // Analisis Finansial Cerdas Berbasis Data Nyata (Context-Aware RAG Lokal)
  Future<String> askFinancialAdvisor({
    required String userQuestion,
    required double totalBalance,
    required double monthlyIncome,
    required double monthlyExpense,
    required List<TransactionItem> currentMonthTransactions,
    required List<CategoryItem> categories,
    required List<Wallet> wallets,
    double? totalSavings,
    double? monthlySavingsIn,
  }) async {
    final apiKey = getApiKey();
    if (apiKey.isEmpty) {
      return "⚠️ Kunci API belum diatur. Silakan buka tab Setelan -> Pengaturan AI untuk memasukkan API Key Gemini / OpenAI pribadi Anda.";
    }

    // Bangun rekap statistik pengeluaran per kategori
    final catMap = {for (var c in categories) c.id: c.name};
    final Map<String, double> categorySpending = {};
    for (final t in currentMonthTransactions.where((t) => t.type == 'expense')) {
      final catName = catMap[t.categoryId] ?? 'Lain-lain';
      categorySpending[catName] = (categorySpending[catName] ?? 0) + t.amount;
    }

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final spendingBreakdown = categorySpending.entries
        .map((e) => "- ${e.key}: ${currencyFormat.format(e.value)}")
        .join("\n");

    final savingsText = totalSavings != null
        ? "- Total Saldo Tabungan / Celengan: ${currencyFormat.format(totalSavings)}\n- Tabungan Masuk Bulan Ini: ${currencyFormat.format(monthlySavingsIn ?? 0)}"
        : "";

    final promptContext = """
Kamu adalah Assistant AI Finansial cerdas untuk aplikasi "IRITOT".
Tugasmu adalah menganalisis data keuangan pribadi pengguna dan memberikan jawaban yang tajam, ringkas, solutif, ramah, dan berbasis data nyata berikut:

[DATA KEUANGAN PENGGUNA BULAN INI]
- Total Saldo Semua Dompet: ${currencyFormat.format(totalBalance)}
- Pemasukan Bulan Ini: ${currencyFormat.format(monthlyIncome)}
- Pengeluaran Bulan Ini: ${currencyFormat.format(monthlyExpense)}
$savingsText
- Rincian Pengeluaran per Kategori:
$spendingBreakdown
- Jumlah Transaksi Bulan Ini: ${currentMonthTransactions.length}

[PERTANYAAN PENGGUNA]
$userQuestion

Instruksi Respons:
1. Jawab langsung pertanyaan pengguna secara to the point dalam Bahasa Indonesia.
2. Gunakan angka riil dari data di atas. Jangan mengarang data yang tidak ada.
3. Berikan saran praktis dan positif untuk membantu menghemat pengeluaran.
4. Jangan gunakan karakter em dash. Gunakan koma, titik, atau tanda kurung.
""";

    final provider = getProvider();
    try {
      if (provider == 'gemini') {
        return await _callGemini(apiKey, promptContext);
      } else if (provider == 'openai') {
        return await _callOpenAI(apiKey, promptContext);
      } else {
        return await _callOllama(promptContext);
      }
    } catch (e) {
      return "Gagal menghubungi AI: $e. Pastikan koneksi internet dan API Key Anda valid.";
    }
  }

  Future<String> _callGemini(String apiKey, String prompt) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 800,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      return text ?? "Tidak ada respon dari Gemini.";
    } else {
      throw Exception("Gemini HTTP Error ${response.statusCode}: ${response.body}");
    }
  }

  Future<String> _callOpenAI(String apiKey, String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.4,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] as String?;
      return text ?? "Tidak ada respon dari OpenAI.";
    } else {
      throw Exception("OpenAI HTTP Error ${response.statusCode}: ${response.body}");
    }
  }

  Future<String> _callOllama(String prompt) async {
    final endpoint = getCustomEndpoint();
    final url = Uri.parse('$endpoint/api/generate');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.2',
        'prompt': prompt,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String? ?? "Tidak ada respon dari Ollama.";
    } else {
      throw Exception("Ollama HTTP Error ${response.statusCode}: ${response.body}");
    }
  }

  // Parser Pintar untuk Catat Suara / Teks
  Map<String, dynamic> parseOfflineVoiceOrText(
    String input, {
    List<CategoryItem>? categories,
    List<Wallet>? wallets,
  }) {
    final lower = input.toLowerCase();

    // 1. Ekstrak Nominal
    double amount = 0.0;
    final regexRibuan = RegExp(r'(\d+)\s*(rb|ribu|k)');
    final matchRibuan = regexRibuan.firstMatch(lower);
    if (matchRibuan != null) {
      final n = double.tryParse(matchRibuan.group(1) ?? '0') ?? 0;
      amount = n * 1000;
    } else {
      final regexJuta = RegExp(r'(\d+([\.,]\d+)?)\s*(jt|juta)');
      final matchJuta = regexJuta.firstMatch(lower);
      if (matchJuta != null) {
        final n = double.tryParse(matchJuta.group(1)?.replaceAll(',', '.') ?? '0') ?? 0;
        amount = n * 1000000;
      } else {
        final regexAngka = RegExp(r'(\d+[\d\.,]*)');
        final matchAngka = regexAngka.firstMatch(lower);
        if (matchAngka != null) {
          final clean = matchAngka.group(1)?.replaceAll('.', '').replaceAll(',', '') ?? '0';
          amount = double.tryParse(clean) ?? 0.0;
        }
      }
    }

    // 2. Tentukan Kategori
    String categoryId = 'cat_food';
    String note = input;
    if (lower.contains('bensin') || lower.contains('ojol') || lower.contains('grab') || lower.contains('gojek') || lower.contains('parkir')) {
      categoryId = 'cat_transport';
    } else if (lower.contains('belanja') || lower.contains('indomaret') || lower.contains('alfamart') || lower.contains('supermarket')) {
      categoryId = 'cat_shopping';
    } else if (lower.contains('listrik') || lower.contains('pulsa') || lower.contains('wifi') || lower.contains('tagihan')) {
      categoryId = 'cat_bills';
    } else if (lower.contains('nonton') || lower.contains('bioskop') || lower.contains('game')) {
      categoryId = 'cat_entertainment';
    } else if (lower.contains('gaji') || lower.contains('transfer masuk') || lower.contains('bonus')) {
      categoryId = 'cat_salary';
    }

    // 3. Tentukan Dompet
    String walletId = 'w_cash';
    if (lower.contains('bca')) {
      walletId = 'w_bca';
    } else if (lower.contains('gopay') || lower.contains('ovo') || lower.contains('dana') || lower.contains('shopeepay')) {
      walletId = 'w_gopay';
    }

    String type = lower.contains('gaji') || lower.contains('pemasukan') || lower.contains('bonus') ? 'income' : 'expense';

    // 4. Sinkronkan dengan kategori & dompet milik pengguna jika disebutkan
    if (categories != null && categories.isNotEmpty) {
      final matched = _matchCategoryByName(lower, categories);
      if (matched != null) {
        categoryId = matched.id;
        type = matched.type;
      } else if (!categories.any((c) => c.id == categoryId)) {
        final sameType = categories.where((c) => c.type == type);
        categoryId = (sameType.isNotEmpty ? sameType.first : categories.first).id;
      }
    }
    if (wallets != null && wallets.isNotEmpty) {
      final matchedWallet = _matchWalletByName(lower, wallets);
      if (matchedWallet != null) {
        walletId = matchedWallet.id;
      } else if (!wallets.any((w) => w.id == walletId)) {
        walletId = wallets.first.id;
      }
    }

    return {
      'amount': amount,
      'categoryId': categoryId,
      'walletId': walletId,
      'note': note,
      'type': type,
    };
  }

  static const Set<String> _categoryStopWords = {'dan', 'and', 'the', 'lain', 'lainnya', 'other', 'umum'};

  // Cari kategori yang namanya (atau salah satu kata utamanya) disebut dalam ucapan
  CategoryItem? _matchCategoryByName(String lowerText, List<CategoryItem> categories) {
    CategoryItem? best;
    int bestScore = 0;
    for (final c in categories) {
      final name = c.name.toLowerCase().trim();
      if (name.isEmpty) continue;
      int score = 0;
      if (lowerText.contains(name)) {
        score = name.length + 100;
      } else {
        for (final word in name.split(RegExp(r'[^a-z0-9]+'))) {
          if (word.length >= 3 && !_categoryStopWords.contains(word) && RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lowerText)) {
            score = score > word.length ? score : word.length;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  Wallet? _matchWalletByName(String lowerText, List<Wallet> wallets) {
    Wallet? best;
    int bestLen = 0;
    for (final w in wallets) {
      final name = w.name.toLowerCase().trim();
      if (name.isEmpty) continue;
      if (lowerText.contains(name) && name.length > bestLen) {
        bestLen = name.length;
        best = w;
      }
    }
    return best;
  }

  // Deteksi Maksud Catat Transaksi dari Pertanyaan / Percakapan Chat
  Map<String, dynamic>? detectTransactionFromQuery({
    required String query,
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
  }) {
    final lower = query.toLowerCase();
    final isLogIntent = lower.contains('catat') ||
        lower.contains('bayar') ||
        lower.contains('beli') ||
        lower.contains('habis') ||
        lower.contains('keluar') ||
        lower.contains('dapat') ||
        lower.contains('gaji') ||
        lower.contains('pemasukan') ||
        lower.contains('pengeluaran') ||
        lower.contains('spent') ||
        lower.contains('bought') ||
        lower.contains('log') ||
        lower.contains('record');

    if (!isLogIntent) return null;

    final parsed = parseOfflineVoiceOrText(query, categories: categories, wallets: wallets);
    final amount = parsed['amount'] as double;
    if (amount <= 0) return null;

    final catId = parsed['categoryId'] as String;
    final catObj = categories.firstWhere(
      (c) => c.id == catId,
      orElse: () => categories.isNotEmpty ? categories.first : CategoryItem(id: 'cat_food', name: 'Makanan', type: 'expense', icon: 'restaurant', colorValue: 0xFFF59E0B),
    );
    final walletId = parsed['walletId'] as String;
    final walletObj = wallets.firstWhere(
      (w) => w.id == walletId,
      orElse: () => wallets.isNotEmpty ? wallets.first : Wallet(id: 'w_cash', name: 'Kas', balance: 0, type: 'cash', icon: 'payments', colorValue: 0xFF10B981),
    );

    return {
      'type': parsed['type'],
      'amount': amount,
      'categoryId': catObj.id,
      'categoryName': catObj.name,
      'walletId': walletObj.id,
      'walletName': walletObj.name,
      'note': parsed['note'],
    };
  }

  // Analisis Multimodal Struk / Bill Belanja
  Future<Map<String, dynamic>> analyzeReceiptImage({
    required List<int> imageBytes,
    String? filePath,
    String mimeType = 'image/jpeg',
    required List<Wallet> wallets,
    required List<CategoryItem> categories,
  }) async {
    final defaultCat = categories.isNotEmpty ? categories.first.id : 'cat_food';
    final defaultWallet = wallets.isNotEmpty ? wallets.first.id : 'w_cash';

    // 1. Coba Gemini Vision jika API Key tersedia
    final apiKey = getApiKey();
    if (apiKey.isNotEmpty && getProvider() == 'gemini') {
      try {
        final base64Image = base64Encode(imageBytes);
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

        final prompt = """
Analisis gambar struk / nota / billing pembayaran ini secara teliti.
Ekstrak informasi penting dan kembalikan HANYA format JSON valid tanpa format markdown:
{
  "merchant": "Nama toko / merchant / tempat / judul billing saja",
  "amount": total_nominal_akhir_angka_saja,
  "date": "yyyy-MM-dd",
  "category": "makanan / belanja / transportasi / tagihan / hiburan / umum",
  "note": "HANYA nama toko / merchant / judul billing saja tanpa rincian item belanja"
}
Contoh: {"merchant": "SUSHIRO", "amount": 278355, "date": "2026-10-25", "category": "makanan", "note": "SUSHIRO"}
ATURAN PENTING:
- "amount" harus berupa angka total tagihan akhir / Grand Total (termasuk pajak & service bila ada).
- "note" dan "merchant" HANYA berisi judul billing / nama merchant (misal: "SUSHIRO"). JANGAN masukkan rincian menu / barang ke note.
""";

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': base64Image,
                    }
                  },
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 300,
            }
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
          final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
          final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;

          final merchant = parsed['merchant']?.toString() ?? 'Struk Belanja';
          final amount = double.tryParse(parsed['amount']?.toString() ?? '0') ?? 0.0;
          final dateStr = parsed['date']?.toString();
          final categoryHint = parsed['category']?.toString().toLowerCase() ?? 'belanja';
          // Aturan: note hanya berisi judul billing / merchant saja
          final note = (parsed['note'] != null && parsed['note'].toString().trim().isNotEmpty)
              ? parsed['note'].toString().trim()
              : merchant;

          DateTime parsedDate = DateTime.now();
          if (dateStr != null) {
            parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
          }

          final matchedCat = _matchCategory(categoryHint, categories);

          if (amount > 0) {
            return {
              'success': true,
              'merchant': merchant,
              'amount': amount,
              'date': parsedDate,
              'categoryId': matchedCat,
              'walletId': defaultWallet,
              'note': note,
            };
          }
        }
      } catch (_) {
        // Fallback jika API gagal atau timeout
      }
    }

    // 2. Offline OCR Engine (Windows Built-in OCR)
    if (!kIsWeb && Platform.isWindows) {
      final ocrResult = await _runWindowsOcr(imageBytes, filePath, categories, wallets);
      if (ocrResult != null && (ocrResult['amount'] as double? ?? 0.0) > 0) {
        return ocrResult;
      }
    }

    // 3. Fallback default
    return {
      'success': true,
      'merchant': 'Struk Pembelian',
      'amount': 0.0,
      'date': DateTime.now(),
      'categoryId': defaultCat,
      'walletId': defaultWallet,
      'note': 'Struk Pembelian',
      'isFallback': true,
    };
  }

  Future<Map<String, dynamic>?> _runWindowsOcr(
    List<int> imageBytes,
    String? filePath,
    List<CategoryItem> categories,
    List<Wallet> wallets,
  ) async {
    try {
      File? tempFile;
      String targetPath = filePath ?? '';
      if (targetPath.isEmpty || !File(targetPath).existsSync()) {
        final tempDir = Directory.systemTemp;
        tempFile = File('${tempDir.path}/iritot_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(imageBytes);
        targetPath = tempFile.path;
      }

      final escapedPath = targetPath.replaceAll("'", "''");

      final psScript = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.Runtime.WindowsRuntime") | Out-Null
\$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq 'AsTask' -and \$_.IsGenericMethod -and \$_.GetParameters().Count -eq 1 } | Select-Object -First 1

function Await(\$winRtTask, \$targetType) {
    \$global:asTaskGeneric.MakeGenericMethod(\$targetType).Invoke(\$null, @(\$winRtTask)).Result
}

[Windows.Media.Ocr.OcrEngine, Windows.Foundation.Metadata, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.Metadata, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation.Metadata, ContentType = WindowsRuntime] | Out-Null

\$path = (Resolve-Path '$escapedPath').Path
\$fileTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync(\$path)
\$file = Await \$fileTask ([Windows.Storage.StorageFile])

\$streamTask = \$file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
\$stream = Await \$streamTask ([Windows.Storage.Streams.IRandomAccessStream])

\$decoderTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync(\$stream)
\$decoder = Await \$decoderTask ([Windows.Graphics.Imaging.BitmapDecoder])

\$bitmapTask = \$decoder.GetSoftwareBitmapAsync()
\$bitmap = Await \$bitmapTask ([Windows.Graphics.Imaging.SoftwareBitmap])

\$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if (-not \$engine) { \$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US')) }

\$ocrTask = \$engine.RecognizeAsync(\$bitmap)
\$ocrResult = Await \$ocrTask ([Windows.Media.Ocr.OcrResult])

foreach (\$line in \$ocrResult.Lines) {
    Write-Output \$line.Text
}
''';

      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript],
      );

      if (tempFile != null && tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (res.exitCode == 0) {
        final lines = LineSplitter.split(res.stdout.toString())
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          return _parseReceiptOcrLines(lines, categories, wallets);
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _parseReceiptOcrLines(
    List<String> lines,
    List<CategoryItem> categories,
    List<Wallet> wallets,
  ) {
    // 1. Ekstrak Judul / Merchant (Tittle Billing)
    final ignoredTitlePatterns = RegExp(
      r'^(npwp|rct|t\d+|tel|phone|pax|store|terminal|table|order|inv|date|waktu|jam|kasir|cashier|pos|receipt|bill|struk|jalan|jl\.|mall|floor|lantai|you have been)',
      caseSensitive: false,
    );

    String title = 'Struk Belanja';
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final clean = line.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
      if (clean.length >= 3 && !ignoredTitlePatterns.hasMatch(clean)) {
        title = line;
        break;
      }
    }

    // 2. Ekstrak Tanggal Transaksi
    DateTime parsedDate = DateTime.now();
    final dateRegex = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');
    for (final line in lines) {
      final m = dateRegex.firstMatch(line);
      if (m != null) {
        final day = int.tryParse(m.group(1)!) ?? 1;
        final month = int.tryParse(m.group(2)!) ?? 1;
        var year = int.tryParse(m.group(3)!) ?? DateTime.now().year;
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          parsedDate = DateTime(year, month, day);
          break;
        }
      }
    }

    // 3. Ekstrak Total Nominal (Amount)
    final ignoredNumberLinePrefixes = RegExp(
      r'^(npwp|rct|t\d+|tel|phone|pax|store|terminal|table|order|inv|date|waktu|jam|invitation)',
      caseSensitive: false,
    );

    final foundAmounts = <double>[];
    double totalFromKeywordLine = 0.0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (ignoredNumberLinePrefixes.hasMatch(line)) continue;

      final isTotalKeyword = RegExp(r'(total\s*tendered|grand\s*total|total\s*bayar|total\s*akhir|tagihan)', caseSensitive: false).hasMatch(line) ||
          (RegExp(r'\btotal\b', caseSensitive: false).hasMatch(line) && !line.toLowerCase().contains('sub'));

      final hasRp = RegExp(r'rp', caseSensitive: false).hasMatch(line);

      // Normalisasi karakter angka yang sering salah terbaca OCR (misal: S -> 5, O/o -> 0 di dalam angka)
      final lineFixed = line
          .replaceAllMapped(RegExp(r'(?<=\d|[rR][pP])[\s]*[oO](?=\d|[\.,\s]|$)', caseSensitive: false), (m) => '0')
          .replaceAllMapped(RegExp(r'(?<=\d)[\s]*[sS](?=\d|[\.,\s]|$)', caseSensitive: false), (m) => '5')
          .replaceAllMapped(RegExp(r'(?<=\d)[\s]*[sS]$', caseSensitive: false), (m) => '5');

      final matches = RegExp(r'(?:rp[\s\.]*)?([0-9]{1,3}(?:[,\.][0-9]{3})*(?:[,\.][0-9]{1,2})?|[0-9]{4,9})', caseSensitive: false).allMatches(lineFixed);

      for (final m in matches) {
        final raw = m.group(1);
        if (raw == null) continue;

        String cleaned = raw.replaceAll(' ', '');
        if (cleaned.contains(',') && cleaned.contains('.')) {
          cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
        } else if (cleaned.contains(',') || cleaned.contains('.')) {
          final parts = cleaned.split(RegExp(r'[,\.]'));
          if (parts.length == 2 && parts[1].length == 3) {
            cleaned = parts[0] + parts[1];
          } else if (parts.length > 2) {
            cleaned = parts.join('');
          } else if (parts.length == 2 && parts[1].length != 3) {
            cleaned = cleaned.replaceAll(',', '.');
          }
        }

        final val = double.tryParse(cleaned) ?? 0.0;
        if (val >= 100 && val <= 100000000) {
          if (hasRp || isTotalKeyword) {
            foundAmounts.add(val);
            if (isTotalKeyword && val > totalFromKeywordLine) {
              totalFromKeywordLine = val;
            }
          }
        }
      }
    }

    double finalAmount = 0.0;
    if (totalFromKeywordLine > 0) {
      finalAmount = totalFromKeywordLine;
    }
    if (foundAmounts.isNotEmpty) {
      foundAmounts.sort();
      final maxAmount = foundAmounts.last;
      if (maxAmount > finalAmount) {
        finalAmount = maxAmount;
      }
    }

    // 4. Kategori Otomatis
    final fullText = lines.join(' ').toLowerCase();
    String categoryHint = 'belanja';
    if (fullText.contains('sushi') || fullText.contains('ramen') || fullText.contains('resto') || fullText.contains('dish') || fullText.contains('cafe') || fullText.contains('makan')) {
      categoryHint = 'makanan';
    } else if (fullText.contains('indomaret') || fullText.contains('alfamart') || fullText.contains('mart') || fullText.contains('supermarket')) {
      categoryHint = 'belanja';
    } else if (fullText.contains('pln') || fullText.contains('listrik') || fullText.contains('pdam') || fullText.contains('wifi') || fullText.contains('telkom')) {
      categoryHint = 'tagihan';
    } else if (fullText.contains('spbu') || fullText.contains('pertamina') || fullText.contains('bensin') || fullText.contains('shell')) {
      categoryHint = 'transportasi';
    }

    final matchedCat = _matchCategory(categoryHint, categories);
    final defaultWallet = wallets.isNotEmpty ? wallets.first.id : 'w_cash';

    return {
      'success': true,
      'merchant': title,
      'amount': finalAmount,
      'date': parsedDate,
      'categoryId': matchedCat,
      'walletId': defaultWallet,
      'note': title, // Aturan user: note nya isi dari tittle billing nya saja
      'isOcr': true,
    };
  }

  String _matchCategory(String hint, List<CategoryItem> categories) {
    final lower = hint.toLowerCase();
    for (final c in categories) {
      if (lower.contains(c.name.toLowerCase()) || c.name.toLowerCase().contains(lower)) {
        return c.id;
      }
    }
    if (lower.contains('makan') || lower.contains('food') || lower.contains('minum') || lower.contains('resto') || lower.contains('cafe')) {
      final f = categories.where((c) => c.id == 'cat_food');
      if (f.isNotEmpty) return f.first.id;
    }
    if (lower.contains('belanja') || lower.contains('shop') || lower.contains('mart') || lower.contains('pasar')) {
      final s = categories.where((c) => c.id == 'cat_shopping');
      if (s.isNotEmpty) return s.first.id;
    }
    if (lower.contains('trans') || lower.contains('bensin') || lower.contains('ojol') || lower.contains('fuel')) {
      final t = categories.where((c) => c.id == 'cat_transport');
      if (t.isNotEmpty) return t.first.id;
    }
    return categories.isNotEmpty ? categories.first.id : 'cat_food';
  }
}
