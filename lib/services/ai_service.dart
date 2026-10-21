import 'dart:convert';
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

  static Future<AiService> init() async {
    final prefs = await SharedPreferences.getInstance();
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
  Map<String, dynamic> parseOfflineVoiceOrText(String input) {
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

    return {
      'amount': amount,
      'categoryId': categoryId,
      'walletId': walletId,
      'note': note,
      'type': lower.contains('gaji') || lower.contains('pemasukan') || lower.contains('bonus') ? 'income' : 'expense',
    };
  }
}
