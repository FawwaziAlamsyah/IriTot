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
      // Default Wallets
      final defaultWallets = [
        Wallet(
          id: 'w_cash',
          name: 'Dompet Tunai',
          type: 'cash',
          balance: 450000.0,
          icon: 'payments',
          colorValue: 0xFF10B981,
        ),
        Wallet(
          id: 'w_bca',
          name: 'Bank BCA',
          type: 'bank',
          balance: 12400000.0,
          icon: 'account_balance',
          colorValue: 0xFF38BDF8,
        ),
        Wallet(
          id: 'w_gopay',
          name: 'GoPay / E-Wallet',
          type: 'ewallet',
          balance: 2000000.0,
          icon: 'phone_android',
          colorValue: 0xFF8B5CF6,
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

      final now = DateTime.now();

      // Default Budgets for current month
      final defaultBudgets = [
        Budget(
          id: 'b_food',
          categoryId: 'cat_food',
          monthlyLimit: 2500000.0,
          month: now.month,
          year: now.year,
        ),
        Budget(
          id: 'b_transport',
          categoryId: 'cat_transport',
          monthlyLimit: 1000000.0,
          month: now.month,
          year: now.year,
        ),
        Budget(
          id: 'b_shopping',
          categoryId: 'cat_shopping',
          monthlyLimit: 1500000.0,
          month: now.month,
          year: now.year,
        ),
      ];

      // Default Seed Transactions
      final defaultTransactions = [
        TransactionItem(
          id: _uuid.v4(),
          walletId: 'w_bca',
          categoryId: 'cat_salary',
          type: 'income',
          amount: 6500000.0,
          note: 'Gaji Pokok Awal Bulan',
          date: DateTime(now.year, now.month, 1, 9, 0),
        ),
        TransactionItem(
          id: _uuid.v4(),
          walletId: 'w_cash',
          categoryId: 'cat_food',
          type: 'expense',
          amount: 25000.0,
          note: 'Makan Siang Nasi Padang',
          date: DateTime(now.year, now.month, now.day, 12, 30),
        ),
        TransactionItem(
          id: _uuid.v4(),
          walletId: 'w_gopay',
          categoryId: 'cat_food',
          type: 'expense',
          amount: 18000.0,
          note: 'Es Kopi Susu Aren',
          date: DateTime(now.year, now.month, now.day, 9, 15),
        ),
        TransactionItem(
          id: _uuid.v4(),
          walletId: 'w_bca',
          categoryId: 'cat_transport',
          type: 'expense',
          amount: 35000.0,
          note: 'Isi Bensin Pertamax',
          date: DateTime(now.year, now.month, now.day - 1, 17, 20),
        ),
        TransactionItem(
          id: _uuid.v4(),
          walletId: 'w_bca',
          categoryId: 'cat_shopping',
          type: 'expense',
          amount: 114500.0,
          note: 'Belanja Mingguan Superindo',
          date: DateTime(now.year, now.month, now.day - 2, 19, 45),
        ),
      ];

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
      final now = DateTime.now();

      final defaultPockets = [
        SavingsPocket(
          id: 'sp_emergency',
          name: 'Dana Darurat',
          targetAmount: 15000000.0,
          currentAmount: 6500000.0,
          colorValue: 0xFF10B981,
          icon: 'security',
          targetDate: DateTime(now.year + 1, 12, 31),
          notes: 'Target 6 bulan biaya hidup darurat',
          createdAt: DateTime(now.year, now.month - 2, 1),
        ),
        SavingsPocket(
          id: 'sp_laptop',
          name: 'Beli Gadget / Laptop',
          targetAmount: 12000000.0,
          currentAmount: 4000000.0,
          colorValue: 0xFF38BDF8,
          icon: 'devices',
          targetDate: DateTime(now.year, now.month + 3, 30),
          notes: 'Upgrade perangkat kerja harian',
          createdAt: DateTime(now.year, now.month - 1, 1),
        ),
        SavingsPocket(
          id: 'sp_holiday',
          name: 'Liburan Akhir Tahun',
          targetAmount: 5000000.0,
          currentAmount: 2000000.0,
          colorValue: 0xFF8B5CF6,
          icon: 'flight_takeoff',
          targetDate: DateTime(now.year, 12, 25),
          notes: 'Tiket & penginapan liburan keluarga',
          createdAt: DateTime(now.year, now.month, 1),
        ),
      ];

      final defaultRecords = [
        SavingsRecord(
          id: _uuid.v4(),
          pocketId: 'sp_emergency',
          pocketName: 'Dana Darurat',
          walletId: 'w_bca',
          walletName: 'Bank BCA',
          type: 'in',
          amount: 2500000.0,
          note: 'Alokasi tabungan awal bulan dari gaji',
          date: DateTime(now.year, now.month, 2, 10, 0),
        ),
        SavingsRecord(
          id: _uuid.v4(),
          pocketId: 'sp_laptop',
          pocketName: 'Beli Gadget / Laptop',
          walletId: 'w_bca',
          walletName: 'Bank BCA',
          type: 'in',
          amount: 1500000.0,
          note: 'Tabungan rutin bulanan',
          date: DateTime(now.year, now.month, 5, 14, 30),
        ),
        SavingsRecord(
          id: _uuid.v4(),
          pocketId: 'sp_holiday',
          pocketName: 'Liburan Akhir Tahun',
          walletId: 'w_gopay',
          walletName: 'GoPay / E-Wallet',
          type: 'in',
          amount: 1000000.0,
          note: 'Sisa saldo cashback & reward',
          date: DateTime(now.year, now.month, 10, 16, 20),
        ),
        SavingsRecord(
          id: _uuid.v4(),
          pocketId: 'sp_holiday',
          pocketName: 'Liburan Akhir Tahun',
          walletId: 'w_cash',
          walletName: 'Dompet Tunai',
          type: 'out',
          amount: 250000.0,
          note: 'Tarik DP booking tiket promo',
          date: DateTime(now.year, now.month, 12, 19, 0),
        ),
      ];

      await saveSavingsPockets(defaultPockets);
      await saveSavingsRecords(defaultRecords);
    }
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

  // --- Categories ---
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

  // --- Budgets ---
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

  Future<void> deleteTransaction(String id) async {
    final transactions = getTransactions();
    final index = transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final item = transactions[index];
    final wallets = getWallets();
    final wallet = wallets.firstWhere(
      (w) => w.id == item.walletId,
      orElse: () => wallets.first,
    );

    // Revert balance
    if (item.type == 'expense') {
      wallet.balance += item.amount;
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

  // ==========================================
  // --- FITUR TABUNGAN (SAVINGS & GOALS) ---
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

  // Setor Tabungan (Masuk / Deposit)
  Future<void> depositToSavings({
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

    // 1. Tambah saldo tabungan
    pocket.currentAmount += amount;

    // 2. Potong saldo dompet sumber
    wallet.balance -= amount;

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
      note: note.trim().isEmpty ? 'Setoran tabungan' : note.trim(),
      date: date ?? DateTime.now(),
    ));

    await saveSavingsPockets(pockets);
    await saveWallets(wallets);
    await saveSavingsRecords(records);
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
