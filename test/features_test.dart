import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iritot/services/storage_service.dart';
import 'package:iritot/models/wallet.dart';
import 'package:iritot/models/category.dart';
import 'package:iritot/models/transaction_item.dart';
import 'package:iritot/models/savings_pocket.dart';
import 'package:iritot/services/csv_service.dart';
import 'package:iritot/services/ai_service.dart';
import 'package:iritot/models/savings_record.dart';
import 'package:iritot/widgets/currency_input_formatter.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Daily, Weekly, and Monthly spending calculations', () async {
    final storage = await StorageService.init();
    final now = DateTime.now();

    // Add a test expense today
    await storage.addTransaction(TransactionItem(
      id: 'tx_today',
      walletId: 'w_cash',
      categoryId: 'cat_food',
      amount: 50000,
      type: 'expense',
      note: 'Makan siang hari ini',
      date: now,
    ));

    // Daily expense
    expect(storage.getDailyExpense(now), 50000);
    expect(storage.getWeeklyExpense(now), 50000);
    expect(storage.getMonthlyExpense(now.month, now.year), 50000);

    final dailyTx = storage.getPeriodTransactions('daily', now);
    expect(dailyTx.length, 1);
    expect(dailyTx.first.id, 'tx_today');
  });

  test('Wallet deletion rules: cannot delete last wallet, can delete when multiple', () async {
    final storage = await StorageService.init();

    // Initial state: only 1 wallet (Dompet Utama)
    final initialWallets = storage.getWallets();
    expect(initialWallets.length, 1);

    // Attempting to delete the only wallet should fail
    final deleteLastResult = await storage.deleteWallet(initialWallets.first.id);
    expect(deleteLastResult, false);
    expect(storage.getWallets().length, 1);

    // Add a second wallet
    await storage.addWallet(Wallet(
      id: 'w_bank_bca',
      name: 'Bank BCA',
      type: 'bank',
      balance: 100000,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    ));
    expect(storage.getWallets().length, 2);

    // Deleting one wallet when 2 exist should succeed
    final deleteResult = await storage.deleteWallet('w_bank_bca');
    expect(deleteResult, true);
    expect(storage.getWallets().length, 1);
    expect(storage.getWallets().first.id, 'w_cash');
  });

  test('Category addition and deletion', () async {
    final storage = await StorageService.init();
    final initialCount = storage.getCategories().length;

    // Add custom category
    final customCat = CategoryItem(
      id: 'cat_gym',
      name: 'Gym & Fitness',
      type: 'expense',
      icon: 'fitness_center',
      colorValue: 0xFFF43F5E,
    );
    await storage.addCategory(customCat);
    expect(storage.getCategories().length, initialCount + 1);

    // Delete custom category
    await storage.deleteCategory('cat_gym');
    expect(storage.getCategories().length, initialCount);
    expect(storage.getCategories().any((c) => c.id == 'cat_gym'), false);
  });

  test('Budget deletion for category', () async {
    final storage = await StorageService.init();
    final now = DateTime.now();

    // Set budget
    await storage.setBudget('cat_food', 500000, now.month, now.year);
    var budgets = storage.getBudgets(now.month, now.year);
    expect(budgets.any((b) => b.categoryId == 'cat_food'), true);

    // Delete budget
    await storage.deleteBudget('cat_food', now.month, now.year);
    budgets = storage.getBudgets(now.month, now.year);
    expect(budgets.any((b) => b.categoryId == 'cat_food'), false);
  });

  test('Savings pocket deletion with automatic balance refund to wallet', () async {
    final storage = await StorageService.init();
    final starterWallet = storage.getWallets().first;
    expect(starterWallet.balance, 0.0);

    // Create a savings pocket with 200,000 balance
    final pocket = SavingsPocket(
      id: 'pocket_vacation',
      name: 'Liburan Bali',
      targetAmount: 1000000,
      currentAmount: 200000,
      colorValue: 0xFF38BDF8,
      icon: 'beach_access',
      createdAt: DateTime.now(),
    );
    await storage.addSavingsPocket(pocket);
    expect(storage.getSavingsPockets().length, 1);

    // Delete pocket with refund
    await storage.deleteSavingsPocketWithRefund('pocket_vacation');

    // Pocket is deleted
    expect(storage.getSavingsPockets().isEmpty, true);

    // Wallet received the 200,000 refund
    final updatedWallet = storage.getWallets().first;
    expect(updatedWallet.balance, 200000);

    // Refund record exists
    final records = storage.getSavingsRecords();
    expect(records.length, 1);
    expect(records.first.amount, 200000);
    expect(records.first.isOut, true);
  });

  test('CSV Export and Import cycle restores transactions correctly', () async {
    final storage = await StorageService.init();
    final wallets = storage.getWallets();
    final categories = storage.getCategories();

    final tx1 = TransactionItem(
      id: 'tx_csv_1',
      walletId: wallets.first.id,
      categoryId: categories.first.id,
      amount: 75000,
      type: 'expense',
      note: 'Makan bareng teman',
      date: DateTime(2026, 10, 20, 12, 30, 0),
    );

    final csvText = CsvService.exportTransactionsToCsv(
      transactions: [tx1],
      wallets: wallets,
      categories: categories,
    );

    expect(csvText.contains('tx_csv_1'), true);
    expect(csvText.contains('75000'), true);
    expect(csvText.contains('Makan bareng teman'), true);

    // Parse back
    final restored = CsvService.parseCsvToTransactions(
      csvString: csvText,
      wallets: wallets,
      categories: categories,
    );

    expect(restored.length, 1);
    expect(restored.first.id, 'tx_csv_1');
    expect(restored.first.amount, 75000);
    expect(restored.first.note, 'Makan bareng teman');
    expect(restored.first.type, 'expense');
  });

  test('StorageService importTransactions handles duplicates and wallet balance update', () async {
    final storage = await StorageService.init();
    final wallet = storage.getWallets().first;
    wallet.balance = 1000000;
    await storage.saveWallets([wallet]);

    final item1 = TransactionItem(
      id: 'tx_imp_1',
      walletId: wallet.id,
      categoryId: 'cat_food',
      amount: 50000,
      type: 'expense',
      note: 'Imported lunch',
      date: DateTime.now(),
    );

    final item2 = TransactionItem(
      id: 'tx_imp_2',
      walletId: wallet.id,
      categoryId: 'cat_food',
      amount: 200000,
      type: 'income',
      note: 'Imported freelance',
      date: DateTime.now(),
    );

    // Initial import of 2 transactions
    final importedCount = await storage.importTransactions([item1, item2], skipDuplicates: true);
    expect(importedCount, 2);
    expect(storage.getTransactions().length, 2);

    // Wallet balance updated: 1,000,000 - 50,000 + 200,000 = 1,150,000
    expect(storage.getWallets().first.balance, 1150000);

    // Re-importing with skipDuplicates=true should import 0 items and leave balance intact
    final reimportedCount = await storage.importTransactions([item1, item2], skipDuplicates: true);
    expect(reimportedCount, 0);
    expect(storage.getTransactions().length, 2);
    expect(storage.getWallets().first.balance, 1150000);
  });

  test('AiService detects transaction intent from voice and chat query', () async {
    final ai = await AiService.init();
    final storage = await StorageService.init();
    final wallets = storage.getWallets();
    final categories = storage.getCategories();

    // Query 1: Expense with 'catat'
    final res1 = ai.detectTransactionFromQuery(
      query: 'Catat beli nasi goreng 25000 pakai kas',
      wallets: wallets,
      categories: categories,
    );
    expect(res1, isNotNull);
    expect(res1!['amount'], 25000);
    expect(res1['type'], 'expense');
    expect(res1['categoryId'], 'cat_food');

    // Query 2: Income
    final res2 = ai.detectTransactionFromQuery(
      query: 'Dapat gaji bulanan 5000000',
      wallets: wallets,
      categories: categories,
    );
    expect(res2, isNotNull);
    expect(res2!['amount'], 5000000);
    expect(res2['type'], 'income');

    // Query 3: Non-transaction query should return null
    final res3 = ai.detectTransactionFromQuery(
      query: 'Bagaimana cara berhemat bulan ini?',
      wallets: wallets,
      categories: categories,
    );
    expect(res3, isNull);

    // Multimodal receipt analysis offline fallback
    final receiptRes = await ai.analyzeReceiptImage(
      imageBytes: [1, 2, 3],
      wallets: wallets,
      categories: categories,
    );
    expect(receiptRes['success'], isTrue);
    expect(receiptRes.containsKey('merchant'), isTrue);
    expect(receiptRes.containsKey('amount'), isTrue);
  });

  test('OCR scan on contoh_billing.jpeg extracts SUSHIRO title as note and 278355 as amount', () async {
    final ai = await AiService.init();
    final storage = await StorageService.init();
    final billingFile = File('contoh_billing.jpeg');
    if (billingFile.existsSync() && Platform.isWindows) {
      final bytes = await billingFile.readAsBytes();
      final res = await ai.analyzeReceiptImage(
        imageBytes: bytes,
        filePath: billingFile.path,
        wallets: storage.getWallets(),
        categories: storage.getCategories(),
      );
      expect(res['success'], isTrue);
      expect(res['amount'], 278355.0);
      expect(res['note'].toString().toUpperCase(), contains('SUSHIRO'));
      expect(res['merchant'].toString().toUpperCase(), contains('SUSHIRO'));
    }
  }, skip: !Platform.isWindows ? 'Offline WinRT OCR is only supported on Windows' : null);

  test('Voice parser syncs with the user categories and wallets when spoken', () async {
    final ai = await AiService.init();
    final storage = await StorageService.init();
    await storage.addCategory(CategoryItem(
      id: 'cat_gym',
      name: 'Gym & Fitness',
      type: 'expense',
      icon: 'fitness_center',
      colorValue: 0xFFF43F5E,
    ));
    await storage.addWallet(Wallet(
      id: 'w_blu',
      name: 'Blu',
      type: 'bank',
      balance: 0,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    ));

    final parsed = ai.parseOfflineVoiceOrText(
      'bayar membership gym 150 ribu pakai blu',
      categories: storage.getCategories(),
      wallets: storage.getWallets(),
    );
    expect(parsed['categoryId'], 'cat_gym');
    expect(parsed['walletId'], 'w_blu');
    expect(parsed['amount'], 150000);
    expect(parsed['type'], 'expense');
  });

  test('CsvService and StorageService savings/pocket CSV cycle', () async {
    final storage = await StorageService.init();

    const sampleCsv = '''ID,Tanggal,Kantong,Tipe,Nominal,Catatan,Saldo_Akhir
rec_1,2026-01-01 12:00:00,SuperBank,in,10000000,Setoran awal,10000000
rec_2,2026-02-01 12:00:00,SuperBank,in,5000000,Gajian,15000000
rec_3,2026-03-01 12:00:00,Krom,in,20000000,THR,20000000
''';

    expect(CsvService.isSavingsCsv(sampleCsv), isTrue);

    final parsed = CsvService.parseCsvToSavings(sampleCsv);
    expect(parsed.pockets.length, 2);
    expect(parsed.records.length, 3);

    final superbank = parsed.pockets.firstWhere((p) => p.name == 'SuperBank');
    expect(superbank.currentAmount, 15000000);

    final krom = parsed.pockets.firstWhere((p) => p.name == 'Krom');
    expect(krom.currentAmount, 20000000);

    // Import into StorageService
    final imported = await storage.importSavingsData(
      newPockets: parsed.pockets,
      newRecords: parsed.records,
      skipDuplicates: true,
    );
    expect(imported, 3);
    expect(storage.getSavingsPockets().length, 2);
    expect(storage.getSavingsRecords().length, 3);
    expect(storage.getTotalSavingsBalance(), 35000000);

    // Re-import with skipDuplicates
    final reimported = await storage.importSavingsData(
      newPockets: parsed.pockets,
      newRecords: parsed.records,
      skipDuplicates: true,
    );
    expect(reimported, 0);
    expect(storage.getSavingsRecords().length, 3);

    // Export back to CSV
    final exported = CsvService.exportSavingsToCsv(
      pockets: storage.getSavingsPockets(),
      records: storage.getSavingsRecords(),
    );
    expect(exported.contains('SuperBank'), isTrue);
    expect(exported.contains('Krom'), isTrue);
    expect(exported.contains('15000000'), isTrue);
  });

  test('ThousandsSeparatorInputFormatter formats dot separator and parses correctly', () {
    final formatter = ThousandsSeparatorInputFormatter();

    // format helper
    expect(ThousandsSeparatorInputFormatter.format(1000), '1.000');
    expect(ThousandsSeparatorInputFormatter.format(1000000), '1.000.000');
    expect(ThousandsSeparatorInputFormatter.format(250000), '250.000');
    expect(ThousandsSeparatorInputFormatter.format(0), '');

    // parse helper
    expect(ThousandsSeparatorInputFormatter.parse('1.000.000'), 1000000.0);
    expect(ThousandsSeparatorInputFormatter.parse('250.000'), 250000.0);
    expect(ThousandsSeparatorInputFormatter.parse(''), 0.0);

    // formatEditUpdate simulation: typing '1000000'
    final updated = formatter.formatEditUpdate(
      const TextEditingValue(text: '1000'),
      const TextEditingValue(text: '1000000', selection: TextSelection.collapsed(offset: 7)),
    );
    expect(updated.text, '1.000.000');
  });

  test('Savings transfer between pockets updates balances and logs distinct records', () async {
    final storage = await StorageService.init();

    // Create 2 pockets
    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_a',
      name: 'Dana Darurat',
      targetAmount: 5000000,
      currentAmount: 2000000,
      colorValue: 0xFF10B981,
      icon: 'savings',
      createdAt: DateTime.now(),
    ));

    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_b',
      name: 'Liburan Akhir Tahun',
      targetAmount: 3000000,
      currentAmount: 500000,
      colorValue: 0xFF38BDF8,
      icon: 'beach_access',
      createdAt: DateTime.now(),
    ));

    // Transfer 500.000 from pocket_a to pocket_b
    await storage.transferBetweenPockets(
      sourcePocketId: 'pocket_a',
      targetPocketId: 'pocket_b',
      amount: 500000,
      note: 'Reallokasi liburan',
    );

    final pockets = storage.getSavingsPockets();
    final pA = pockets.firstWhere((p) => p.id == 'pocket_a');
    final pB = pockets.firstWhere((p) => p.id == 'pocket_b');

    expect(pA.currentAmount, 1500000);
    expect(pB.currentAmount, 1000000);

    final records = storage.getSavingsRecords();
    expect(records.length, 2);

    final outRec = records.firstWhere((r) => r.pocketId == 'pocket_a');
    expect(outRec.isOut, isTrue);
    expect(outRec.isPocketTransfer, isTrue);
    expect(outRec.amount, 500000);
    expect(outRec.transferType, 'pocket_transfer');

    final inRec = records.firstWhere((r) => r.pocketId == 'pocket_b');
    expect(inRec.isIn, isTrue);
    expect(inRec.isPocketTransfer, isTrue);
    expect(inRec.amount, 500000);
    expect(inRec.transferType, 'pocket_transfer');

    // Insufficient funds guard: try transferring 3.000.000 from pA (has 1.500.000)
    await storage.transferBetweenPockets(
      sourcePocketId: 'pocket_a',
      targetPocketId: 'pocket_b',
      amount: 3000000,
    );
    // Balances should remain untouched
    final pAAfter = storage.getSavingsPockets().firstWhere((p) => p.id == 'pocket_a');
    expect(pAAfter.currentAmount, 1500000);
  });

  test('SavingsRecord serialization preserves transferType and differentiation', () {
    final record = SavingsRecord(
      id: 'rec_x',
      pocketId: 'p1',
      pocketName: 'Pocket 1',
      walletId: 'p2',
      walletName: 'Pocket 2',
      type: 'in',
      amount: 750000,
      note: 'Transfer masuk',
      date: DateTime.now(),
      transferType: 'pocket_transfer',
    );

    final json = record.toJson();
    expect(json['transferType'], 'pocket_transfer');

    final fromJson = SavingsRecord.fromJson(json);
    expect(fromJson.isPocketTransfer, isTrue);
    expect(fromJson.transferType, 'pocket_transfer');
  });

  test('Budget addition, editing, and overwriting preserves limits', () async {
    final storage = await StorageService.init();
    final now = DateTime.now();

    // Set budget
    await storage.setBudget('cat_food', 1500000, now.month, now.year);
    var budgets = storage.getBudgets(now.month, now.year);
    expect(budgets.firstWhere((b) => b.categoryId == 'cat_food').monthlyLimit, 1500000);

    // Edit budget (fix typo or increase)
    await storage.setBudget('cat_food', 2000000, now.month, now.year);
    budgets = storage.getBudgets(now.month, now.year);
    expect(budgets.firstWhere((b) => b.categoryId == 'cat_food').monthlyLimit, 2000000);
  });

  test('depositToSavings creates spending transaction history and updates pocket and wallet balances', () async {
    final storage = await StorageService.init();
    await storage.clearFinancialData();

    // Create a wallet with 5.000.000 balance
    await storage.addWallet(Wallet(
      id: 'w_bank_test',
      name: 'Bank Mandiri',
      type: 'bank',
      balance: 5000000,
      icon: 'account_balance',
      colorValue: 0xFF10B981,
    ));

    // Create a target pocket
    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_emergency',
      name: 'Dana Darurat',
      targetAmount: 10000000,
      currentAmount: 1000000,
      icon: 'savings',
      colorValue: 0xFF38BDF8,
      targetDate: DateTime.now().add(const Duration(days: 90)),
      createdAt: DateTime.now(),
    ));

    // Deposit 500.000 without custom note
    final now = DateTime.now();
    await storage.depositToSavings(
      pocketId: 'pocket_emergency',
      walletId: 'w_bank_test',
      amount: 500000,
      note: '',
      date: now,
    );

    // Verify pocket balance updated
    final pocketAfter = storage.getSavingsPockets().firstWhere((p) => p.id == 'pocket_emergency');
    expect(pocketAfter.currentAmount, 1500000);

    // Verify wallet balance deducted
    final walletAfter = storage.getWallets().firstWhere((w) => w.id == 'w_bank_test');
    expect(walletAfter.balance, 4500000);

    // Verify savings records has deposit entry
    final records = storage.getSavingsRecords();
    expect(records.any((r) => r.pocketId == 'pocket_emergency' && r.amount == 500000), isTrue);

    // Verify transaction history in spending
    final transactions = storage.getTransactions();
    expect(transactions.length, 1);
    final tx = transactions.first;
    expect(tx.walletId, 'w_bank_test');
    expect(tx.amount, 500000);
    expect(tx.type, 'expense');
    expect(tx.note, 'Deposit to "Dana Darurat" Pocket');
    expect(tx.categoryId, 'cat_savings');

    // Verify spending calculations in home screen
    expect(storage.getDailyExpense(now), 500000);
    expect(storage.getMonthlyExpense(now.month, now.year), 500000);
    expect(storage.getPeriodTransactions('daily', now).length, 1);

    // Deposit again with a custom note
    await storage.depositToSavings(
      pocketId: 'pocket_emergency',
      walletId: 'w_bank_test',
      amount: 250000,
      note: 'Bonus lembur',
      date: now,
    );

    final transactions2 = storage.getTransactions();
    expect(transactions2.length, 2);
    final tx2 = transactions2.firstWhere((t) => t.amount == 250000);
    expect(tx2.note, 'Deposit to "Dana Darurat" Pocket (Bonus lembur)');
  });

  test('updateWallet updates wallet attributes and balance correctly', () async {
    final storage = await StorageService.init();
    final wallets = storage.getWallets();
    final firstWallet = wallets.first;

    final updated = Wallet(
      id: firstWallet.id,
      name: 'Dompet Utama Renamed',
      type: 'bank',
      balance: 10000000,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    );

    await storage.updateWallet(updated);
    final walletAfter = storage.getWallets().firstWhere((w) => w.id == firstWallet.id);
    expect(walletAfter.name, 'Dompet Utama Renamed');
    expect(walletAfter.type, 'bank');
    expect(walletAfter.balance, 10000000);
  });
}
