import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/transaction_item.dart';
import '../models/budget.dart';
import '../models/savings_pocket.dart';
import '../models/savings_record.dart';

class StorageService {
  static const String _keyWallets = 'iritot_wallets';
  static const String _keyCategories = 'iritot_categories';
  static const String _keyTransactions = 'iritot_transactions';
  static const String _keyBudgets = 'iritot_budgets';
  static const String _keySavingsPockets = 'iritot_savings_pockets';
  static const String _keySavingsRecords = 'iritot_savings_records';
  static const String _keyIsInit = 'iritot_initialized';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();

  StorageService(this._prefs);

  static Future<StorageService> init([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final service = StorageService(prefs);
    await service._seedInitialDataIfNeeded();
    await service._seedSavingsIfNeeded();
    return service;
  }

  Future<void> _seedInitialDataIfNeeded() async {
    final isInit = _prefs.getBool(_keyIsInit) ?? false;
    if (!isInit) {
      // Clean starter wallet with zero balance
      final defaultWallets = [
        Wallet(
          id: 'w_cash',
          name: 'Dompet Utama',
          type: 'cash',
          balance: 0.0,
          icon: 'account_balance_wallet',
          colorValue: 0xFF10B981,
        ),
      ];

      // Default Categories
      final defaultCategories = [
        CategoryItem(
          id: 'cat_food',
          name: 'Makan & Minum',
          type: 'expense',
          icon: 'restaurant',
          colorValue: 0xFFF59E0B,
        ),
        CategoryItem(
          id: 'cat_transport',
          name: 'Transport & Bensin',
          type: 'expense',
          icon: 'local_gas_station',
          colorValue: 0xFF38BDF8,
        ),
        CategoryItem(
          id: 'cat_shopping',
          name: 'Belanja Kebutuhan',
          type: 'expense',
          icon: 'shopping_bag',
          colorValue: 0xFFF43F5E,
        ),
        CategoryItem(
          id: 'cat_bills',
          name: 'Tagihan & Listrik',
          type: 'expense',
          icon: 'receipt_long',
          colorValue: 0xFF8B5CF6,
        ),
        CategoryItem(
          id: 'cat_entertainment',
          name: 'Hiburan & Liburan',
          type: 'expense',
          icon: 'movie',
          colorValue: 0xFFEC4899,
        ),
        CategoryItem(
          id: 'cat_salary',
          name: 'Gaji & Pendapatan',
          type: 'income',
          icon: 'payments',
          colorValue: 0xFF10B981,
        ),
        CategoryItem(
          id: 'cat_freelance',
          name: 'Side Project / Bonus',
          type: 'income',
          icon: 'trending_up',
          colorValue: 0xFF14B8A6,
        ),
        CategoryItem(
          id: 'cat_transfer',
          name: 'Transfer Antar Dompet',
          type: 'transfer',
          icon: 'swap_horiz',
          colorValue: 0xFF64748B,
        ),
        CategoryItem(
          id: 'cat_savings',
          name: 'Alokasi Tabungan',
          type: 'expense',
          icon: 'savings',
          colorValue: 0xFF10B981,
        ),
      ];

      final List<Budget> defaultBudgets = [];
      final List<TransactionItem> defaultTransactions = [];

      await saveWallets(defaultWallets);
      await saveCategories(defaultCategories);
      await saveBudgets(defaultBudgets);
      await saveTransactions(defaultTransactions);
      await _prefs.setBool(_keyIsInit, true);
    }
  }

  Future<void> _seedSavingsIfNeeded() async {
    final rawPockets = _prefs.getString(_keySavingsPockets);
    if (rawPockets == null) {
      final List<SavingsPocket> defaultPockets = [];
      final List<SavingsRecord> defaultRecords = [];

      await saveSavingsPockets(defaultPockets);
      await saveSavingsRecords(defaultRecords);
    }
  }

  // Bersihkan seluruh data transaksi dan kembalikan ke kondisi awal bersih
  Future<void> clearFinancialData() async {
    await _prefs.remove(_keyWallets);
    await _prefs.remove(_keyTransactions);
    await _prefs.remove(_keyBudgets);
    await _prefs.remove(_keySavingsPockets);
    await _prefs.remove(_keySavingsRecords);
    await _prefs.remove(_keyIsInit);
    await _seedInitialDataIfNeeded();
    await _seedSavingsIfNeeded();
  }

  // --- Wallets ---
  List<Wallet> getWallets() {
    final raw = _prefs.getString(_keyWallets);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.map((e) => Wallet.fromJson(e)).toList();
  }

  Future<void> saveWallets(List<Wallet> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyWallets, raw);
  }

  Future<void> addWallet(Wallet wallet) async {
    final wallets = getWallets();
    wallets.add(wallet);
    await saveWallets(wallets);
  }

  Future<void> updateWallet(Wallet wallet) async {
    final wallets = getWallets();
    final index = wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      wallets[index] = wallet;
      await saveWallets(wallets);
    }
  }

  Future<bool> deleteWallet(String id) async {
    final wallets = getWallets();
    if (wallets.length <= 1) return false;
    wallets.removeWhere((w) => w.id == id);
    await saveWallets(wallets);
    return true;
  }

  // Categories
  List<CategoryItem> getCategories() {
    final raw = _prefs.getString(_keyCategories);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.map((e) => CategoryItem.fromJson(e)).toList();
  }

  Future<void> saveCategories(List<CategoryItem> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCategories, raw);
  }

  Future<void> addCategory(CategoryItem category) async {
    final categories = getCategories();
    categories.add(category);
    await saveCategories(categories);
  }

  Future<void> deleteCategory(String id) async {
    final categories = getCategories();
    categories.removeWhere((c) => c.id == id);
    await saveCategories(categories);
  }

  // Budgets
  List<Budget> getBudgets(int month, int year) {
    final raw = _prefs.getString(_keyBudgets);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => Budget.fromJson(e))
        .where((b) => b.month == month && b.year == year)
        .toList();
  }

  Future<void> saveBudgets(List<Budget> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyBudgets, raw);
  }

  Future<void> setBudget(String categoryId, double limit, int month, int year) async {
    final raw = _prefs.getString(_keyBudgets);
    List<Budget> all = [];
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      all = decoded.map((e) => Budget.fromJson(e)).toList();
    }
    all.removeWhere((b) => b.categoryId == categoryId && b.month == month && b.year == year);
    all.add(Budget(
      id: _uuid.v4(),
      categoryId: categoryId,
      monthlyLimit: limit,
      month: month,
      year: year,
    ));
    await saveBudgets(all);
  }

  Future<void> deleteBudget(String categoryId, int month, int year) async {
    final raw = _prefs.getString(_keyBudgets);
    List<Budget> all = [];
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      all = decoded.map((e) => Budget.fromJson(e)).toList();
    }
    all.removeWhere((b) => b.categoryId == categoryId && b.month == month && b.year == year);
    await saveBudgets(all);
  }

  // --- Transactions ---
  List<TransactionItem> getTransactions() {
    final raw = _prefs.getString(_keyTransactions);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    final list = decoded.map((e) => TransactionItem.fromJson(e)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveTransactions(List<TransactionItem> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyTransactions, raw);
  }

  Future<void> addTransaction(TransactionItem item) async {
    final transactions = getTransactions();
    transactions.add(item);
    await saveTransactions(transactions);

    // Update wallet balance otomatis
    final wallets = getWallets();
    final wallet = wallets.firstWhere(
      (w) => w.id == item.walletId,
      orElse: () => wallets.first,
    );

    if (item.type == 'expense') {
      wallet.balance -= item.amount;
      if (item.categoryId.isNotEmpty &&
          item.categoryId != 'no_category' &&
          item.categoryId != 'cat_transfer') {
        final now = item.date;
        final allBudgets = getBudgets(now.month, now.year);
        final bIdx = allBudgets.indexWhere((b) => b.categoryId == item.categoryId);
        if (bIdx != -1) {
          final newLimit = (allBudgets[bIdx].monthlyLimit - item.amount).clamp(0.0, double.infinity);
          await setBudget(item.categoryId, newLimit, now.month, now.year);
        }
      }
    } else if (item.type == 'income') {
      wallet.balance += item.amount;
    } else if (item.type == 'transfer' && item.destinationWalletId != null) {
      wallet.balance -= item.amount;
      final destWallet = wallets.firstWhere(
        (w) => w.id == item.destinationWalletId,
        orElse: () => wallets.first,
      );
      destWallet.balance += item.amount;
    }

    await saveWallets(wallets);
  }

  /// Impor transaksi dari cadangan CSV.
  /// [skipDuplicates] jika true, akan mengabaikan transaksi dengan ID yang sudah ada di penyimpanan.
  /// Mengembalikan jumlah transaksi yang berhasil ditambahkan.
  Future<int> importTransactions(
    List<TransactionItem> importedItems, {
    bool skipDuplicates = true,
  }) async {
    if (importedItems.isEmpty) return 0;

    final currentTransactions = getTransactions();
    final existingIds = currentTransactions.map((t) => t.id).toSet();

    final List<TransactionItem> toAdd = [];
    for (int i = 0; i < importedItems.length; i++) {
      final item = importedItems[i];
      if (skipDuplicates && existingIds.contains(item.id)) {
        continue;
      }

      final finalId = item.id.trim().isNotEmpty && (!existingIds.contains(item.id) || skipDuplicates)
          ? item.id
          : 'tx_imp_${DateTime.now().microsecondsSinceEpoch}_$i';

      toAdd.add(TransactionItem(
        id: finalId,
        walletId: item.walletId,
        destinationWalletId: item.destinationWalletId,
        categoryId: item.categoryId,
        type: item.type,
        amount: item.amount,
        note: item.note,
        date: item.date,
      ));
      existingIds.add(finalId);
    }

    if (toAdd.isEmpty) return 0;

    currentTransactions.addAll(toAdd);
    await saveTransactions(currentTransactions);

    // Perbarui saldo dompet untuk transaksi yang baru diimpor
    final wallets = getWallets();
    final walletMap = {for (var w in wallets) w.id: w};

    for (final item in toAdd) {
      final wallet = walletMap[item.walletId] ?? (wallets.isNotEmpty ? wallets.first : null);
      if (wallet != null) {
        if (item.type == 'expense') {
          wallet.balance -= item.amount;
        } else if (item.type == 'income') {
          wallet.balance += item.amount;
        } else if (item.type == 'transfer' && item.destinationWalletId != null) {
          wallet.balance -= item.amount;
          final destWallet = walletMap[item.destinationWalletId];
          if (destWallet != null) {
            destWallet.balance += item.amount;
          }
        }
      }
    }

    await saveWallets(wallets);
    return toAdd.length;
  }

  bool canDeleteTransaction(TransactionItem item) {
    final diff = DateTime.now().difference(item.date);
    return diff.inDays <= 7;
  }

  Future<bool> deleteTransaction(String id) async {
    final transactions = getTransactions();
    final index = transactions.indexWhere((t) => t.id == id);
    if (index == -1) return false;

    final item = transactions[index];
    if (!canDeleteTransaction(item)) {
      return false;
    }

    final wallets = getWallets();
    final wallet = wallets.firstWhere(
      (w) => w.id == item.walletId,
      orElse: () => wallets.first,
    );

    // Revert balance
    if (item.type == 'expense') {
      wallet.balance += item.amount;
      if (item.categoryId.isNotEmpty &&
          item.categoryId != 'no_category' &&
          item.categoryId != 'cat_transfer') {
        final now = item.date;
        final allBudgets = getBudgets(now.month, now.year);
        final bIdx = allBudgets.indexWhere((b) => b.categoryId == item.categoryId);
        if (bIdx != -1) {
          final newLimit = allBudgets[bIdx].monthlyLimit + item.amount;
          await setBudget(item.categoryId, newLimit, now.month, now.year);
        }
      }
    } else if (item.type == 'income') {
      wallet.balance -= item.amount;
    } else if (item.type == 'transfer' && item.destinationWalletId != null) {
      wallet.balance += item.amount;
      final destWallet = wallets.firstWhere(
        (w) => w.id == item.destinationWalletId,
        orElse: () => wallets.first,
      );
      destWallet.balance -= item.amount;
    }

    transactions.removeAt(index);
    await saveTransactions(transactions);
    await saveWallets(wallets);
    return true;
  }

  double getTotalBalance() {
    final wallets = getWallets();
    return wallets.fold(0.0, (sum, w) => sum + w.balance);
  }

  double getMonthlyIncome(int month, int year) {
    final list = getTransactions().where((t) =>
        t.date.month == month && t.date.year == year && t.type == 'income');
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyExpense(int month, int year) {
    final list = getTransactions().where((t) =>
        t.date.month == month && t.date.year == year && t.type == 'expense');
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getDailyIncome(DateTime date) {
    final list = getTransactions().where((t) =>
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day &&
        t.type == 'income');
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getDailyExpense(DateTime date) {
    final list = getTransactions().where((t) =>
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day &&
        t.type == 'expense');
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getWeeklyIncome(DateTime date) {
    final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final list = getTransactions().where((t) =>
        t.type == 'income' &&
        !t.date.isBefore(startOfWeek) &&
        t.date.isBefore(endOfWeek));
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  double getWeeklyExpense(DateTime date) {
    final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final list = getTransactions().where((t) =>
        t.type == 'expense' &&
        !t.date.isBefore(startOfWeek) &&
        t.date.isBefore(endOfWeek));
    return list.fold(0.0, (sum, t) => sum + t.amount);
  }

  List<TransactionItem> getPeriodTransactions(String period, DateTime date) {
    final all = getTransactions();
    if (period == 'daily') {
      return all.where((t) =>
          t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day).toList();
    } else if (period == 'weekly') {
      final startOfWeek = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      return all.where((t) =>
          !t.date.isBefore(startOfWeek) &&
          t.date.isBefore(endOfWeek)).toList();
    } else {
      return all.where((t) =>
          t.date.year == date.year &&
          t.date.month == date.month).toList();
    }
  }

  // ==========================================
  // FITUR TABUNGAN (SAVINGS & GOALS)
  // ==========================================

  List<SavingsPocket> getSavingsPockets() {
    final raw = _prefs.getString(_keySavingsPockets);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.map((e) => SavingsPocket.fromJson(e)).toList();
  }

  Future<void> saveSavingsPockets(List<SavingsPocket> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keySavingsPockets, raw);
  }

  Future<void> addSavingsPocket(SavingsPocket pocket) async {
    final list = getSavingsPockets();
    list.add(pocket);
    await saveSavingsPockets(list);
  }

  Future<void> updateSavingsPocket(SavingsPocket pocket) async {
    final list = getSavingsPockets();
    final index = list.indexWhere((p) => p.id == pocket.id);
    if (index != -1) {
      list[index] = pocket;
      await saveSavingsPockets(list);
    }
  }

  Future<void> deleteSavingsPocket(String id) async {
    final list = getSavingsPockets();
    list.removeWhere((p) => p.id == id);
    await saveSavingsPockets(list);
  }

  Future<void> deleteSavingsPocketWithRefund(String pocketId, {String? targetWalletId}) async {
    final pockets = getSavingsPockets();
    final index = pockets.indexWhere((p) => p.id == pocketId);
    if (index == -1) return;

    final pocket = pockets[index];
    if (pocket.currentAmount > 0) {
      final wallets = getWallets();
      final wallet = targetWalletId != null
          ? wallets.firstWhere((w) => w.id == targetWalletId, orElse: () => wallets.first)
          : wallets.first;
      wallet.balance += pocket.currentAmount;
      await saveWallets(wallets);

      final records = getSavingsRecords();
      records.add(SavingsRecord(
        id: _uuid.v4(),
        pocketId: pocket.id,
        pocketName: pocket.name,
        walletId: wallet.id,
        walletName: wallet.name,
        amount: pocket.currentAmount,
        type: 'out',
        note: 'Penutupan pos kantong: ${pocket.name}',
        date: DateTime.now(),
      ));
      await saveSavingsRecords(records);
    }

    pockets.removeAt(index);
    await saveSavingsPockets(pockets);
  }

  List<SavingsRecord> getSavingsRecords() {
    final raw = _prefs.getString(_keySavingsRecords);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    final list = decoded.map((e) => SavingsRecord.fromJson(e)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveSavingsRecords(List<SavingsRecord> list) async {
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs.setString(_keySavingsRecords, raw);
  }

  // Import Kantong Tabungan dan Riwayat Mutasi dari CSV
  Future<int> importSavingsData({
    required List<SavingsPocket> newPockets,
    required List<SavingsRecord> newRecords,
    bool skipDuplicates = true,
  }) async {
    final existingPockets = getSavingsPockets();
    final existingRecords = getSavingsRecords();

    final pocketMap = {for (var p in existingPockets) p.name.trim().toLowerCase(): p};

    for (final np in newPockets) {
      final key = np.name.trim().toLowerCase();
      if (!pocketMap.containsKey(key)) {
        existingPockets.add(np);
        pocketMap[key] = np;
      } else {
        // Perbarui saldo terkini
        final existing = pocketMap[key]!;
        existing.currentAmount = np.currentAmount;
      }
    }

    final existingRecordIds = {for (var r in existingRecords) r.id};
    final existingSignatures = {
      for (var r in existingRecords)
        '${r.pocketName}_${r.date.toIso8601String()}_${r.amount}_${r.type}'
    };

    int addedCount = 0;
    for (final nr in newRecords) {
      final sig = '${nr.pocketName}_${nr.date.toIso8601String()}_${nr.amount}_${nr.type}';
      if (skipDuplicates && (existingRecordIds.contains(nr.id) || existingSignatures.contains(sig))) {
        continue;
      }
      existingRecords.add(nr);
      addedCount++;
    }

    await saveSavingsPockets(existingPockets);
    await saveSavingsRecords(existingRecords);
    return addedCount;
  }

  // Setor Tabungan (Masuk / Deposit)
  Future<void> depositToSavings({
    required String pocketId,
    required String walletId,
    required double amount,
    required String note,
    DateTime? date,
  }) async {
    if (amount <= 0) return;

    final pockets = getSavingsPockets();
    final pocket = pockets.firstWhere((p) => p.id == pocketId);

    final wallets = getWallets();
    final wallet = wallets.firstWhere((w) => w.id == walletId);

    final txDate = date ?? DateTime.now();
    final trimmedNote = note.trim();

    // 1. Tambah saldo tabungan
    pocket.currentAmount += amount;

    // 2. Potong saldo dompet sumber
    wallet.balance -= amount;

    // Format catatan transaksi dan riwayat tabungan
    final String spendingNote;
    if (trimmedNote.isEmpty) {
      spendingNote = 'Deposit to "${pocket.name}" Pocket';
    } else if (trimmedNote.toLowerCase().startsWith('deposit to')) {
      spendingNote = trimmedNote;
    } else {
      spendingNote = 'Deposit to "${pocket.name}" Pocket ($trimmedNote)';
    }

    final String savingsRecordNote = trimmedNote.isEmpty
        ? 'Deposit to "${pocket.name}" Pocket'
        : trimmedNote;

    // 3. Catat riwayat mutasi tabungan
    final records = getSavingsRecords();
    records.add(SavingsRecord(
      id: _uuid.v4(),
      pocketId: pocket.id,
      pocketName: pocket.name,
      walletId: wallet.id,
      walletName: wallet.name,
      type: 'in',
      amount: amount,
      note: savingsRecordNote,
      date: txDate,
    ));

    // 4. Cari atau buat kategori alokasi tabungan
    final categories = getCategories();
    CategoryItem? savingsCat = categories.where((c) => c.id == 'cat_savings').firstOrNull;
    savingsCat ??= categories.where((c) =>
      c.name.toLowerCase().contains('tabung') ||
      c.name.toLowerCase().contains('saving') ||
      c.name.toLowerCase().contains('pocket')
    ).firstOrNull;
    if (savingsCat == null) {
      savingsCat = CategoryItem(
        id: 'cat_savings',
        name: 'Alokasi Tabungan',
        type: 'expense',
        icon: 'savings',
        colorValue: 0xFF10B981,
      );
      categories.add(savingsCat);
      await saveCategories(categories);
    }

    // 5. Catat ke riwayat transaksi belanja / spending page
    final transactions = getTransactions();
    transactions.add(TransactionItem(
      id: _uuid.v4(),
      walletId: wallet.id,
      categoryId: savingsCat.id,
      type: 'expense',
      amount: amount,
      note: spendingNote,
      date: txDate,
    ));

    await saveSavingsPockets(pockets);
    await saveWallets(wallets);
    await saveSavingsRecords(records);
    await saveTransactions(transactions);
  }

  // Tarik Tabungan (Keluar / Withdraw)
  Future<void> withdrawFromSavings({
    required String pocketId,
    required String walletId,
    required double amount,
    required String note,
    DateTime? date,
  }) async {
    final pockets = getSavingsPockets();
    final pocket = pockets.firstWhere((p) => p.id == pocketId);

    final wallets = getWallets();
    final wallet = wallets.firstWhere((w) => w.id == walletId);

    // 1. Kurangi saldo tabungan
    pocket.currentAmount -= amount;
    if (pocket.currentAmount < 0) pocket.currentAmount = 0;

    // 2. Tambah saldo dompet penerima
    wallet.balance += amount;

    // 3. Catat riwayat mutasi tabungan
    final records = getSavingsRecords();
    records.add(SavingsRecord(
      id: _uuid.v4(),
      pocketId: pocket.id,
      pocketName: pocket.name,
      walletId: wallet.id,
      walletName: wallet.name,
      type: 'out',
      amount: amount,
      note: note.trim().isEmpty ? 'Penarikan tabungan' : note.trim(),
      date: date ?? DateTime.now(),
    ));

    await saveSavingsPockets(pockets);
    await saveWallets(wallets);
    await saveSavingsRecords(records);
  }

  // Pindah Dana Antar Pos Tabungan (Transfer antar Pocket)
  Future<void> transferBetweenPockets({
    required String sourcePocketId,
    required String targetPocketId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final pockets = getSavingsPockets();
    final sourceIndex = pockets.indexWhere((p) => p.id == sourcePocketId);
    final targetIndex = pockets.indexWhere((p) => p.id == targetPocketId);

    if (sourceIndex == -1 || targetIndex == -1 || sourcePocketId == targetPocketId) {
      return;
    }

    final sourcePocket = pockets[sourceIndex];
    final targetPocket = pockets[targetIndex];

    if (sourcePocket.currentAmount < amount || amount <= 0) {
      return;
    }

    // 1. Kurangi saldo pos sumber
    sourcePocket.currentAmount -= amount;
    if (sourcePocket.currentAmount < 0) sourcePocket.currentAmount = 0;

    // 2. Tambah saldo pos tujuan
    targetPocket.currentAmount += amount;

    final records = getSavingsRecords();
    final txDate = date ?? DateTime.now();
    final customNote = note != null && note.trim().isNotEmpty ? note.trim() : null;

    // 3. Catat mutasi keluar untuk pos sumber
    records.add(SavingsRecord(
      id: _uuid.v4(),
      pocketId: sourcePocket.id,
      pocketName: sourcePocket.name,
      walletId: targetPocket.id,
      walletName: targetPocket.name,
      type: 'out',
      amount: amount,
      transferType: 'pocket_transfer',
      note: customNote != null ? 'Pindah ke ${targetPocket.name} ($customNote)' : 'Transfer ke pos ${targetPocket.name}',
      date: txDate,
    ));

    // 4. Catat mutasi masuk untuk pos tujuan
    records.add(SavingsRecord(
      id: _uuid.v4(),
      pocketId: targetPocket.id,
      pocketName: targetPocket.name,
      walletId: sourcePocket.id,
      walletName: sourcePocket.name,
      type: 'in',
      amount: amount,
      transferType: 'pocket_transfer',
      note: customNote != null ? 'Terima dari ${sourcePocket.name} ($customNote)' : 'Transfer dari pos ${sourcePocket.name}',
      date: txDate,
    ));

    await saveSavingsPockets(pockets);
    await saveSavingsRecords(records);
  }

  // Total saldo akumulasi seluruh kantong tabungan
  double getTotalSavingsBalance() {
    final pockets = getSavingsPockets();
    return pockets.fold(0.0, (sum, p) => sum + p.currentAmount);
  }

  // Total uang masuk ke tabungan bulan ini
  double getMonthlySavingsIn(int month, int year) {
    final records = getSavingsRecords().where((r) =>
        r.type == 'in' && r.date.month == month && r.date.year == year);
    return records.fold(0.0, (sum, r) => sum + r.amount);
  }

  // Total uang ditarik dari tabungan bulan ini
  double getMonthlySavingsOut(int month, int year) {
    final records = getSavingsRecords().where((r) =>
        r.type == 'out' && r.date.month == month && r.date.year == year);
    return records.fold(0.0, (sum, r) => sum + r.amount);
  }

  // Pertumbuhan tabungan bersih bulan ini (Masuk - Keluar)
  double getNetSavingsGrowth(int month, int year) {
    return getMonthlySavingsIn(month, year) - getMonthlySavingsOut(month, year);
  }
}
