import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iritot/services/storage_service.dart';
import 'package:iritot/models/wallet.dart';
import 'package:iritot/models/category.dart';
import 'package:iritot/models/transaction_item.dart';
import 'package:iritot/models/savings_pocket.dart';
import 'package:iritot/services/csv_service.dart';
import 'package:iritot/services/ai_service.dart';

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
}
