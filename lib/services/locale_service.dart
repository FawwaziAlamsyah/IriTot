import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _keyLocale = 'iritot_app_language';
  static const String defaultLocale = 'en';

  final SharedPreferences _prefs;
  late String _currentLocale;

  LocaleService(this._prefs) {
    _currentLocale = _prefs.getString(_keyLocale) ?? defaultLocale;
  }

  static Future<LocaleService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocaleService(prefs);
  }

  String get currentLocale => _currentLocale;
  bool get isEnglish => _currentLocale == 'en';
  bool get isIndonesian => _currentLocale == 'id';

  Future<void> setLocale(String langCode) async {
    if (_currentLocale != langCode) {
      _currentLocale = langCode;
      await _prefs.setString(_keyLocale, langCode);
      notifyListeners();
    }
  }

  String t(String key) {
    return _translations[_currentLocale]?[key] ?? _translations['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // General & Common
      'appName': 'IRITOT',
      'appTagline': 'Personal Finance Tracker • 100% Offline Local',
      'personalBadge': 'PERSONAL',
      'offlineBadge': '100% Offline on Phone',
      'active': 'Active',
      'save': 'Save',
      'cancel': 'Cancel',
      'close': 'Close',
      'delete': 'Delete',
      'add': 'Add',
      'manage': 'Manage',
      'seeAll': 'See All',
      'monthYear': 'October 2026',

      // Navigation Bar
      'navHome': 'Home',
      'navSavings': 'Savings',
      'navLog': 'Log',
      'navReports': 'Reports',
      'navSettings': 'Settings',

      // Splash Screen
      'splashBadge': '⚡ SMART WEALTH FLOW',
      'splashSubtitle': 'Ready to track smart spendings',
      'splashDecryption': 'Securing offline local vault...',

      // Main Screen Tabs (Blu Style)
      'tabDailySpending': 'Daily Spending',
      'tabSavings': 'Savings',

      // Login Screen
      'loginTitle': 'Sign In to Your Account',
      'loginSubtitle': 'Local authentication stored on your phone.',
      'username': 'Username',
      'usernameHint': 'Enter username',
      'password': 'Password',
      'passwordHint': 'Enter password',
      'rememberMe': 'Remember Me',
      'signInBtn': 'Sign In to IRITOT',
      'errEmptyLogin': 'Username and password are required.',
      'errInvalidLogin': 'Incorrect username or password. Please try again.',
      'sessionTimeoutMsg': 'Session expired after 5 minutes of inactivity. Please sign in again.',
      'autoLockChip': 'Auto-Lock: 5 min',
      'autoLockDesc': 'Auto-locks if app is in background for over 5 minutes',

      // Account & Security in Settings
      'secAccountSecurity': 'ACCOUNT & LOCAL SECURITY',
      'changeCredentialsTitle': 'Change Username & Password',
      'changeCredentialsSubtitle': 'Verify with current credentials',
      'changeCredentialsDesc': 'Enter your current username & password for verification.',
      'oldUsernameLabel': 'Current Username:',
      'oldUsernameHint': 'Current username',
      'oldPasswordLabel': 'Current Password:',
      'oldPasswordHint': 'Current password',
      'newUsernameLabel': 'New Username:',
      'newUsernameHint': 'e.g. aji_finance',
      'newPasswordLabel': 'New Password:',
      'newPasswordHint': 'At least 4 characters',
      'confirmPasswordLabel': 'Confirm New Password:',
      'confirmPasswordHint': 'Repeat new password',
      'saveChanges': 'Save Changes',
      'credentialsUpdatedSuccess': 'Username and password successfully updated locally!',
      'errOldRequired': 'Current username and password are required.',
      'errNewUserEmpty': 'New username cannot be empty.',
      'errNewPassShort': 'New password must be at least 4 characters.',
      'errPassMismatch': 'New passwords do not match.',
      'logoutTitle': 'Lock App (Log Out)',
      'logoutSubtitle': 'Lock app session for privacy',
      'logoutDialogTitle': 'Lock App / Log Out',
      'logoutDialogDesc': 'The app will be locked. You will need your username and password to log in again.',
      'lockAndExit': 'Lock & Log Out',

      // Language Section in Settings
      'secLanguage': 'LANGUAGE PREFERENCE',
      'appLanguage': 'App Language',
      'langEnglish': 'English (Default)',
      'langIndonesian': 'Bahasa Indonesia',
      'langChanged': 'Language changed to English',

      // Wallets & Accounts in Settings
      'secWallets': 'MY WALLETS & ACCOUNTS',
      'addWalletTitle': 'Add Wallet / Account',
      'walletNameLabel': 'Wallet / Bank Name:',
      'walletNameHint': 'e.g. Cash, Bank BCA, GoPay',
      'initialBalanceLabel': 'Initial Balance (Rp):',
      'walletTypeLabel': 'Wallet Type:',
      'typeCash': 'Physical Cash',
      'typeBank': 'Bank Account',
      'typeEWallet': 'E-Wallet',

      // Data & Backup in Settings
      'secBackup': 'DATA & BACKUP (OFFLINE)',
      'exportCsvTitle': 'Export Transactions to CSV',
      'exportCsvSubtitle': 'Backup data to spreadsheet file',
      'exportModalTitle': 'CSV Universal Backup',
      'copyCsv': 'Copy CSV',
      'csvCopied': 'CSV file copied to clipboard!',

      // AI Settings
      'secAi': 'AI ASSISTANT (PERSONAL BYOK)',
      'aiConnected': 'Connected',
      'aiNoKey': 'No Key Set',
      'aiDesc': 'API keys are stored strictly on your device. Your AI quota will never be shared or used by anyone else.',
      'aiProvider': 'AI Provider:',
      'aiApiKey': 'Personal API Key:',
      'aiEndpoint': 'Ollama Endpoint URL:',
      'saveAiBtn': 'Save AI Settings',
      'aiSavedSuccess': 'API settings saved to local device secure storage.',

      // Home Screen
      'totalCashBalance': 'TOTAL CASH BALANCE',
      'hide': 'Hide',
      'show': 'Show',
      'income': 'Income',
      'expense': 'Expense',
      'secSavings': 'SAVINGS & POCKETS',
      'totalSaved': 'Total Saved',
      'quickActions': 'QUICK ACTIONS',
      'actionLog': 'Log Expense',
      'actionVoice': 'Voice AI',
      'actionScan': 'Scan Receipt',
      'secBudget': 'MONTHLY BUDGET PROGRESS',
      'safeDailyBudget': 'Safe Daily Budget:',
      'secRecentTransactions': 'RECENT TRANSACTIONS',
      'noTransactions': 'No transactions recorded yet',
      'today': 'Today',
      'yesterday': 'Yesterday',

      // Savings Screen
      'savingsScreenTitle': 'Savings & Pockets',
      'totalSavings': 'TOTAL SAVINGS',
      'target': 'Target',
      'deposit': 'Deposit',
      'withdraw': 'Withdraw',
      'secSavingsTargets': 'SAVINGS TARGETS',
      'newPocket': 'New Pocket',
      'secSavingsHistory': 'SAVINGS HISTORY',
      'addDepositTitle': 'Deposit Savings',
      'withdrawTitle': 'Withdraw Savings',
      'fromWallet': 'From Wallet:',
      'toWallet': 'To Wallet:',
      'pocketTarget': 'Savings Pocket:',
      'nominal': 'Amount (Rp):',
      'noteOptional': 'Notes (Optional):',
      'inflow': 'Inflow',
      'outflow': 'Outflow',

      // Reports Screen
      'reportsTitle': 'Financial Reports',
      'monthlyOverview': 'Monthly Overview',
      'netCashflow': 'Net Cashflow',
      'secExpenseByCategory': 'EXPENSE BY CATEGORY',
      'highestExpense': 'Highest Expense',
      'totalCashOut': 'Total Outflow',
    },
    'id': {
      // General & Common
      'appName': 'IRITOT',
      'appTagline': 'Catat Keuangan Pribadi • 100% Offline Lokal',
      'personalBadge': 'PRIBADI',
      'offlineBadge': '100% Offline Lokal di HP',
      'active': 'Aktif',
      'save': 'Simpan',
      'cancel': 'Batal',
      'close': 'Tutup',
      'delete': 'Hapus',
      'add': 'Tambah',
      'manage': 'Kelola',
      'seeAll': 'Lihat Semua',
      'monthYear': 'Oktober 2026',

      // Navigation Bar
      'navHome': 'Beranda',
      'navSavings': 'Tabungan',
      'navLog': 'Catat',
      'navReports': 'Laporan',
      'navSettings': 'Setelan',

      // Splash Screen
      'splashBadge': '⚡ SMART WEALTH FLOW',
      'splashSubtitle': 'Kelola keuangan harian lebih cerdas',
      'splashDecryption': 'Mengamankan brankas lokal...',

      // Main Screen Tabs (Blu Style)
      'tabDailySpending': 'Pemakaian Sehari-hari',
      'tabSavings': 'Tabungan',

      // Login Screen
      'loginTitle': 'Masuk ke Akun Anda',
      'loginSubtitle': 'Autentikasi lokal di penyimpanan memori HP Anda.',
      'username': 'Username',
      'usernameHint': 'Masukkan username',
      'password': 'Password',
      'passwordHint': 'Masukkan password',
      'rememberMe': 'Ingat Saya',
      'signInBtn': 'Masuk ke IRITOT',
      'errEmptyLogin': 'Username dan password wajib diisi.',
      'errInvalidLogin': 'Username atau password salah. Silakan coba lagi.',
      'sessionTimeoutMsg': 'Sesi telah berakhir karena keluar aplikasi lebih dari 5 menit. Silakan login kembali.',
      'autoLockChip': 'Kunci Otomatis: 5 mnt',
      'autoLockDesc': 'Kunci otomatis jika keluar aplikasi lebih dari 5 menit',

      // Account & Security in Settings
      'secAccountSecurity': 'AKUN & KEAMANAN LOKAL',
      'changeCredentialsTitle': 'Ubah Username & Password',
      'changeCredentialsSubtitle': 'Verifikasi dengan kredensial lama',
      'changeCredentialsDesc': 'Masukkan username & password lama sebagai verifikasi keamanan.',
      'oldUsernameLabel': 'Username Lama:',
      'oldUsernameHint': 'Username saat ini',
      'oldPasswordLabel': 'Password Lama:',
      'oldPasswordHint': 'Password saat ini',
      'newUsernameLabel': 'Username Baru:',
      'newUsernameHint': 'Contoh: aji_finance',
      'newPasswordLabel': 'Password Baru:',
      'newPasswordHint': 'Minimal 4 karakter',
      'confirmPasswordLabel': 'Konfirmasi Password Baru:',
      'confirmPasswordHint': 'Ulangi password baru',
      'saveChanges': 'Simpan Perubahan',
      'credentialsUpdatedSuccess': 'Username dan password berhasil diperbarui secara lokal!',
      'errOldRequired': 'Username dan password lama wajib diisi.',
      'errNewUserEmpty': 'Username baru tidak boleh kosong.',
      'errNewPassShort': 'Password baru minimal 4 karakter.',
      'errPassMismatch': 'Konfirmasi password baru tidak cocok.',
      'logoutTitle': 'Kunci Aplikasi (Logout)',
      'logoutSubtitle': 'Kunci sesi aplikasi demi privasi',
      'logoutDialogTitle': 'Kunci Aplikasi / Keluar',
      'logoutDialogDesc': 'Aplikasi akan dikunci. Anda perlu memasukkan username dan password Anda untuk masuk kembali.',
      'lockAndExit': 'Kunci & Keluar',

      // Language Section in Settings
      'secLanguage': 'PILIHAN BAHASA',
      'appLanguage': 'Bahasa Aplikasi',
      'langEnglish': 'Bahasa Inggris (Default)',
      'langIndonesian': 'Bahasa Indonesia',
      'langChanged': 'Bahasa diubah ke Bahasa Indonesia',

      // Wallets & Accounts in Settings
      'secWallets': 'DOMPET & REKENING SAYA',
      'addWalletTitle': 'Tambah Dompet / Rekening',
      'walletNameLabel': 'Nama Dompet / Bank:',
      'walletNameHint': 'Contoh: Bank Jago, Dana, dll.',
      'initialBalanceLabel': 'Saldo Awal (Rp):',
      'walletTypeLabel': 'Tipe Dompet:',
      'typeCash': 'Uang Tunai / Kas',
      'typeBank': 'Rekening Bank',
      'typeEWallet': 'E-Wallet',

      // Data & Backup in Settings
      'secBackup': 'DATA & CADANGAN (BACKUP)',
      'exportCsvTitle': 'Ekspor Transaksi ke CSV',
      'exportCsvSubtitle': 'Cadangkan data ke file spreadsheet',
      'exportModalTitle': 'Ekspor Cadangan CSV',
      'copyCsv': 'Salin CSV',
      'csvCopied': 'File CSV disalin ke Clipboard!',

      // AI Settings
      'secAi': 'ASSISTANT AI (BYOK PRIBADI)',
      'aiConnected': 'Terhubung',
      'aiNoKey': 'Belum Ada Key',
      'aiDesc': 'Kunci API disimpan murni di perangkat Anda. Kuota AI tidak akan pernah dibagi atau dipakai orang lain.',
      'aiProvider': 'Provider AI:',
      'aiApiKey': 'Kunci API Pribadi:',
      'aiEndpoint': 'Endpoint URL Ollama:',
      'saveAiBtn': 'Simpan Pengaturan AI',
      'aiSavedSuccess': 'Pengaturan Kunci API tersimpan di penyimpanan aman lokal HP.',

      // Home Screen
      'totalCashBalance': 'TOTAL SALDO KAS',
      'hide': 'Sembunyikan',
      'show': 'Tampilkan',
      'income': 'Pemasukan',
      'expense': 'Pengeluaran',
      'secSavings': 'TABUNGAN & CELENGAN',
      'totalSaved': 'Total Ditabung',
      'quickActions': 'AKSI CEPAT',
      'actionLog': 'Catat Pengeluaran',
      'actionVoice': 'Suara AI',
      'actionScan': 'Scan Struk',
      'secBudget': 'PROGRES ANGGARAN BULANAN',
      'safeDailyBudget': 'Batas Aman Harian:',
      'secRecentTransactions': 'TRANSAKSI TERBARU',
      'noTransactions': 'Belum ada transaksi tercatat',
      'today': 'Hari ini',
      'yesterday': 'Kemarin',

      // Savings Screen
      'savingsScreenTitle': 'Tabungan & Celengan',
      'totalSavings': 'TOTAL TABUNGAN SAYA',
      'target': 'Target',
      'deposit': 'Nabung Masuk',
      'withdraw': 'Tarik Dana',
      'secSavingsTargets': 'TARGET & POS CELENGAN',
      'newPocket': 'Pos Baru',
      'secSavingsHistory': 'RIWAYAT TABUNGAN',
      'addDepositTitle': 'Nabung Masuk',
      'withdrawTitle': 'Tarik Dana Celengan',
      'fromWallet': 'Dari Dompet Kas:',
      'toWallet': 'Pindahkan ke Dompet:',
      'pocketTarget': 'Pilih Pos Tabungan:',
      'nominal': 'Nominal (Rp):',
      'noteOptional': 'Catatan (Opsional):',
      'inflow': 'Masuk',
      'outflow': 'Keluar',

      // Reports Screen
      'reportsTitle': 'Laporan Keuangan',
      'monthlyOverview': 'Ringkasan Bulanan',
      'netCashflow': 'Arus Kas Bersih',
      'secExpenseByCategory': 'PENGELUARAN BERDASARKAN KATEGORI',
      'highestExpense': 'Pengeluaran Terbesar',
      'totalCashOut': 'Total Keluar',
    },
  };
}
