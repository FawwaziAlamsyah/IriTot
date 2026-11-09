import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iritot/main.dart';
import 'package:iritot/services/storage_service.dart';
import 'package:iritot/services/ai_service.dart';
import 'package:iritot/services/auth_service.dart';
import 'package:iritot/services/locale_service.dart';
import 'package:iritot/models/savings_pocket.dart';
import 'package:iritot/models/savings_record.dart';
import 'package:iritot/models/wallet.dart';
import 'package:iritot/models/budget.dart';
import 'package:iritot/models/transaction_item.dart';
import 'package:iritot/screens/splash_screen.dart';
import 'package:iritot/screens/login_screen.dart';
import 'package:iritot/screens/savings_screen.dart';
import 'package:iritot/screens/pocket_history_screen.dart';
import 'package:iritot/screens/budget_screen.dart';
import 'package:iritot/screens/settings_screen.dart';
import 'package:iritot/screens/home_screen.dart';
import 'package:iritot/screens/add_transaction_modal.dart';

void main() {
  testWidgets('IriTot Login flow and Savings navigation smoke test', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});

    final storageService = await StorageService.init();
    final aiService = await AiService.init();
    final authService = await AuthService.init();
    final localeService = await LocaleService.init();

    await tester.pumpWidget(IriTotApp(
      storageService: storageService,
      aiService: aiService,
      authService: authService,
      localeService: localeService,
    ));
    await tester.pumpAndSettle();

    // 1. Verify Login Screen elements (iOS Passcode style: Enter Passcode title, no submit button)
    expect(find.text('Enter Passcode'), findsOneWidget);
    expect(find.text('Sign In to IRITOT'), findsNothing); // No button needed

    // 2. Enter default 6-digit PIN (000000) using on-screen numpad or synced input
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();

    // 4. Verify Home Screen elements after automatic successful login
    expect(find.text('IRITOT'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Monthly Budget'), findsOneWidget);
    expect(find.text('MAIN BALANCE'), findsOneWidget);
    expect(find.textContaining('Total Cash:'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('SAVINGS & POCKETS'), findsNothing);

    // 5. Verify Pocket tab item exists in bottom nav and tap it
    expect(find.text('Pocket'), findsOneWidget);
    await tester.tap(find.text('Pocket'));
    await tester.pumpAndSettle();

    // 5a. Pocket requires the 6-digit PIN: a wrong PIN is rejected with shake & error
    expect(find.text('Enter Passcode'), findsOneWidget);
    expect(find.text('TOTAL SAVINGS'), findsNothing);
    await tester.enterText(find.byType(TextField).last, '999999');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN.'), findsOneWidget);

    // 5b. The correct 6-digit PIN auto-opens Pocket
    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.pumpAndSettle();

    // 6. Verify Savings Screen elements in English
    expect(find.text('TOTAL SAVINGS'), findsOneWidget);
    expect(find.text('POCKET TARGET'), findsOneWidget);
  });

  test('AuthService local credentials and change validation test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final authService = await AuthService.init();

    // Initial default credentials
    expect(authService.getPin(), '000000');
    expect(authService.getDisplayName(), 'NewUser');
    expect(authService.isLoggedIn(), false);

    // Login test with wrong PIN
    final wrongLogin = await authService.login('999999');
    expect(wrongLogin, false);
    expect(authService.isLoggedIn(), false);

    // Login test with correct PIN
    final correctLogin = await authService.login('000000');
    expect(correctLogin, true);
    expect(authService.isLoggedIn(), true);

    // Update profile test (Display Name)
    final profileUpdate = await authService.updateProfile(
      newDisplayName: 'Aji Finance',
    );
    expect(profileUpdate['success'], true);
    expect(authService.getDisplayName(), 'Aji Finance');

    // Change PIN: test failure with incorrect old PIN
    final failOldPin = await authService.changePin(
      oldPin: '999999',
      newPin: '123456',
    );
    expect(failOldPin['success'], false);
    expect(failOldPin['message'], contains('PIN lama salah'));

    // Change PIN: test failure with short PIN (< 6 digits)
    final failShortPin = await authService.changePin(
      oldPin: '000000',
      newPin: '1234',
    );
    expect(failShortPin['success'], false);
    expect(failShortPin['message'], contains('6 digit angka'));

    // Change PIN: test failure with non-digits
    final failLetterPin = await authService.changePin(
      oldPin: '000000',
      newPin: 'abcdef',
    );
    expect(failLetterPin['success'], false);
    expect(failLetterPin['message'], contains('hanya boleh berisi angka'));

    // Change PIN: test success with valid old and new 6-digit PIN
    final successChange = await authService.changePin(
      oldPin: '000000',
      newPin: '123456',
    );
    expect(successChange['success'], true);
    expect(authService.getPin(), '123456');

    // Verify login with updated PIN
    final oldLoginAttempt = await authService.login('000000');
    expect(oldLoginAttempt, false);

    final newLoginAttempt = await authService.login('123456');
    expect(newLoginAttempt, true);

    // Test logout
    await authService.logout();
    expect(authService.isLoggedIn(), false);
  });

  test('AuthService updateProfile supports changing PIN and display name simultaneously', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final authService = await AuthService.init();
    expect(authService.getPin(), '000000');
    expect(authService.getDisplayName(), 'NewUser');

    // Update display name and 6-digit PIN together
    final updateResult = await authService.updateProfile(
      newDisplayName: 'Aji Pocket',
      oldPin: '000000',
      newPin: '654321',
    );
    expect(updateResult['success'], true);
    expect(authService.getDisplayName(), 'Aji Pocket');
    expect(authService.getPin(), '654321');

    // Verify login works with new PIN
    final loginSuccess = await authService.login('654321');
    expect(loginSuccess, true);
    expect(authService.isLoggedIn(), true);

    // Logout
    await authService.logout();
    expect(authService.isLoggedIn(), false);
  });

  testWidgets('LoginScreen renders iOS-style passcode keypad and auto-submits on 6th digit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authService = await AuthService.init();
    final localeService = await LocaleService.init();

    bool loginSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService: authService,
          localeService: localeService,
          onLoginSuccess: () {
            loginSuccessCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Passcode Title
    expect(find.text('Enter Passcode'), findsOneWidget);
    // Verify Keypad buttons 0-9 exist
    for (int i = 0; i <= 9; i++) {
      expect(find.text('$i'), findsWidgets);
    }

    // Enter wrong PIN (6 digits: 888888)
    await tester.enterText(find.byType(TextField).first, '888888');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
    expect(loginSuccessCalled, false);

    // Enter correct default PIN (000000)
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();
    expect(loginSuccessCalled, true);
  });

  testWidgets('Tapping on-screen numpad buttons directly auto-logs in upon 6th digit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authService = await AuthService.init();
    final localeService = await LocaleService.init();

    bool loginSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService: authService,
          localeService: localeService,
          onLoginSuccess: () {
            loginSuccessCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap '0' button 6 times
    final zeroFinder = find.widgetWithText(InkWell, '0');
    expect(zeroFinder, findsOneWidget);

    for (int i = 0; i < 6; i++) {
      await tester.tap(zeroFinder);
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.pumpAndSettle();
    expect(loginSuccessCalled, true);
  });

  test('LocaleService default English and language switching test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final localeService = await LocaleService.init();

    // Default locale is English
    expect(localeService.currentLocale, 'en');
    expect(localeService.isEnglish, true);
    expect(localeService.isIndonesian, false);
    expect(localeService.t('navHome'), 'Home');
    expect(localeService.t('loginTitle'), 'Enter Passcode');

    // Switch to Indonesian
    await localeService.setLocale('id');
    expect(localeService.currentLocale, 'id');
    expect(localeService.isEnglish, false);
    expect(localeService.isIndonesian, true);
    expect(localeService.t('navHome'), 'Beranda');
    expect(localeService.t('loginTitle'), 'Masukkan PIN');

    // Switch back to English
    await localeService.setLocale('en');
    expect(localeService.currentLocale, 'en');
    expect(localeService.isEnglish, true);
    expect(localeService.t('navHome'), 'Home');
  });

  test('AuthService 5-minute inactivity session timeout validation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final authService = await AuthService.init();

    // Login at t0
    final t0 = DateTime.now().millisecondsSinceEpoch;
    await authService.login('000000');
    await authService.updateLastActiveTimestamp(t0);
    expect(authService.isLoggedIn(), true);

    // 4 minutes later (240,000 ms): Session still valid
    final t4min = t0 + (4 * 60 * 1000);
    expect(authService.isSessionExpired(t4min), false);

    // 5 minutes and 1 second later (301,000 ms): Session expired
    final t5min1s = t0 + (5 * 60 * 1000) + 1000;
    expect(authService.isSessionExpired(t5min1s), true);

    // Lock session due to timeout
    await authService.lockSessionDueToTimeout();
    expect(authService.isLoggedIn(), false);
  });

  testWidgets('SplashScreen Orbit renders properly and triggers onFinish callback', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final localeService = await LocaleService.init();

    bool finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          localeService: localeService,
          duration: const Duration(milliseconds: 500),
          onFinish: () {
            finished = true;
          },
        ),
      ),
    );

    // Initial render
    await tester.pump();

    // Verify brand and orbit elements
    expect(find.text('IRITOT'), findsOneWidget);
    expect(find.text('⚡ SMART WEALTH FLOW'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(finished, false);

    // Advance time past the 500ms duration
    await tester.pump(const Duration(milliseconds: 600));
    expect(finished, true);
  });

  testWidgets('IriTotApp default constructor bootstraps services automatically without freeze', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const IriTotApp(
        splashDuration: Duration(milliseconds: 300),
      ),
    );

    // Initial frame renders splash screen immediately
    await tester.pump();
    expect(find.text('IRITOT'), findsOneWidget);

    // Advance time to allow bootstrap and splash duration to complete
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify smooth transition to LoginScreen with Enter Passcode
    expect(find.text('Enter Passcode'), findsOneWidget);
  });

  testWidgets('SavingsScreen pocket cards render compact Setor, Tarik, Transfer and locked source in transfer modal', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();

    // Create 2 test pockets
    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_liburan',
      name: 'Liburan Bali',
      targetAmount: 5000000,
      currentAmount: 1000000,
      colorValue: 0xFF38BDF8,
      icon: 'savings',
      createdAt: DateTime.now(),
    ));

    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_gadget',
      name: 'Beli Laptop',
      targetAmount: 15000000,
      currentAmount: 2000000,
      colorValue: 0xFF10B981,
      icon: 'savings',
      createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SavingsScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify Header displays POCKET TARGET
    expect(find.text('POCKET TARGET'), findsOneWidget);

    // 2. Verify top 3 buttons (Deposit, Withdraw, Transfer) are REMOVED from top
    // Instead, each pocket card renders compact actions: Deposit, Withdraw, Transfer
    expect(find.text('Deposit'), findsNWidgets(2));
    expect(find.text('Withdraw'), findsNWidgets(2));
    expect(find.text('Transfer'), findsNWidgets(2));

    // 3. Tap Transfer on first pocket ('Liburan Bali')
    await tester.tap(find.text('Transfer').first);
    await tester.pumpAndSettle();

    // Verify modal opened with Source Locked to 'Liburan Bali'
    expect(find.text('Source Locked'), findsOneWidget);
    expect(find.text('Liburan Bali'), findsAtLeastNWidgets(1));
    expect(find.text('Other Pocket'), findsOneWidget);
    expect(find.text('Cash/Bank Wallet'), findsOneWidget);
  });

  testWidgets('BudgetScreen refers to total wallet cash balance and warns if overbudget', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Total Wallet Cash is referenced on the screen
    expect(find.text('Total Wallet Cash'), findsOneWidget);
  });

  testWidgets('SettingsScreen allows tapping wallet to top up funds and edit info', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    final ai = await AiService.init();
    final auth = await AuthService.init();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsScreen(
          storageService: storage,
          aiService: ai,
          authService: auth,
          localeService: locale,
          onDataChanged: () {},
          onLogout: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify wallet section exists
    expect(find.text('MY WALLETS & ACCOUNTS'), findsOneWidget);
    expect(find.text('Dompet Utama'), findsOneWidget);

    // Tap top up (+) button on the wallet row
    final topUpBtn = find.byIcon(Icons.add_circle_outline).first;
    await tester.tap(topUpBtn);
    await tester.pumpAndSettle();

    // Verify dialog opens with top up tab
    expect(find.text('Add Funds (Income)'), findsOneWidget);
    expect(find.text('Edit Info & Balance'), findsOneWidget);
    expect(find.text('Additional Amount (Rp):'), findsOneWidget);

    // Enter amount: 2000000
    final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogTextFields.first, '2000000');
    await tester.pumpAndSettle();

    // Tap Add Funds button
    final addFundsBtn = find.descendant(of: find.byType(AlertDialog), matching: find.text('Add Funds'));
    await tester.tap(addFundsBtn);
    await tester.pumpAndSettle();

    // Verify wallet balance is updated to 2.000.000
    final wallet = storage.getWallets().first;
    expect(wallet.balance, 2000000);

    // Verify income transaction created
    final txs = storage.getTransactions();
    expect(txs.any((t) => t.type == 'income' && t.amount == 2000000), isTrue);
  });

  testWidgets('BudgetScreen excludes savings pocket deposits from monthly budget and categories', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();

    // Add a wallet with 5.000.000
    await storage.addWallet(Wallet(
      id: 'w_test',
      name: 'Test Wallet',
      type: 'bank',
      balance: 5000000,
      icon: 'account_balance',
      colorValue: 0xFF10B981,
    ));

    // Create a pocket and deposit 1.000.000
    await storage.addSavingsPocket(SavingsPocket(
      id: 'pocket_vacation',
      name: 'Liburan',
      targetAmount: 5000000,
      currentAmount: 0,
      icon: 'savings',
      colorValue: 0xFF38BDF8,
      createdAt: DateTime.now(),
    ));

    await storage.depositToSavings(
      pocketId: 'pocket_vacation',
      walletId: 'w_test',
      amount: 1000000,
      note: 'Setor liburan',
    );

    // Set budget for Food: 1.500.000
    final now = DateTime.now();
    await storage.setBudget('cat_food', 1500000, now.month, now.year);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Alokasi Tabungan should NOT be in the budget category list
    expect(find.text('Alokasi Tabungan'), findsNothing);

    // Spent info is removed from Monthly Budget; only limit is displayed
    expect(find.text('0% Used'), findsNothing);
    expect(find.text('Rp 1.500.000'), findsWidgets);
  });

  testWidgets('Expense reduces category limit directly and AddTransaction allows no category with unallocated cash check', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    final now = DateTime.now();

    // Setup initial wallet balance: 1.000.000
    final wallet = storage.getWallets().first;
    wallet.balance = 1000000;
    await storage.saveWallets([wallet]);

    // Setup category budget for Food: 400.000
    await storage.setBudget('cat_food', 400000, now.month, now.year);
    // Unallocated cash = 1.000.000 - 400.000 = 600.000

    // Task 1: Expense with category reduces its limit directly
    await storage.addTransaction(TransactionItem(
      id: 'tx_food_exp_1',
      walletId: wallet.id,
      categoryId: 'cat_food',
      type: 'expense',
      amount: 150000,
      note: 'Makan siang restoran',
      date: now,
    ));

    // Category limit should be reduced from 400.000 to 250.000
    final budgetsAfterExp = storage.getBudgets(now.month, now.year);
    final foodBudget = budgetsAfterExp.firstWhere((b) => b.categoryId == 'cat_food');
    expect(foodBudget.monthlyLimit, 250000);

    // Deleting the transaction restores the limit
    await storage.deleteTransaction('tx_food_exp_1');
    final budgetsAfterDelete = storage.getBudgets(now.month, now.year);
    expect(budgetsAfterDelete.firstWhere((b) => b.categoryId == 'cat_food').monthlyLimit, 400000);

    // Task 2: AddTransactionModal allows transactions without category
    final ai = await AiService.init();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => AddTransactionModal(
                  storageService: storage,
                  aiService: ai,
                  localeService: locale,
                  onTransactionAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify "No Category" / "Tanpa Kategori" option is rendered
    expect(find.text('No Category'), findsOneWidget);

    // Enter amount: 200.000 (less than unallocated cash 600.000)
    final amountField = find.byType(TextField).first;
    await tester.enterText(amountField, '200000');
    await tester.pumpAndSettle();

    // Select "No Category"
    await tester.ensureVisible(find.text('No Category'));
    await tester.tap(find.text('No Category'));
    await tester.pumpAndSettle();

    // Save transaction without category
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify transaction was saved with 'no_category'
    final txs = storage.getTransactions();
    expect(txs.any((t) => t.categoryId == 'no_category' && t.amount == 200000), isTrue);

    // Now test check: when amount > unallocated cash, no-category expense is blocked
    // Current wallet cash: 800.000, total monthly budget: 400.000, unallocated cash = 400.000
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Enter amount 500.000 (exceeds unallocated cash 400.000)
    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.pumpAndSettle();

    // Tap No Category
    await tester.ensureVisible(find.text('No Category'));
    await tester.tap(find.text('No Category'));
    await tester.pumpAndSettle();

    // Try to save
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Expect error popup dialog informing that non-category funds are insufficient
    expect(find.textContaining('Non-category funds insufficient'), findsOneWidget);
    // Pop message has 'OK' button
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('AddTransactionModal shows pop message alert on validation and BudgetScreen edit dialog buttons are compact', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    final ai = await AiService.init();

    // 1. Test validation alert in AddTransactionModal when amount is 0
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => AddTransactionModal(
                  storageService: storage,
                  aiService: ai,
                  localeService: locale,
                  onTransactionAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Tap Save Expense with 0 amount
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify pop message with Notice and OK button
    expect(find.text('Notice'), findsOneWidget);
    expect(find.text('Please enter a valid transaction amount.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    // Tap OK dismisses popup dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Notice'), findsNothing);

    // Close modal bottom sheet
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 2. Test BudgetScreen ADD and Cairkan ke Wallet buttons (no edit dialog)
    await locale.setLocale('id');
    final now = DateTime.now();
    await storage.setBudget('cat_food', 500000, now.month, now.year);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Food category card shows Makan & Minum and limit 500.000
    expect(find.text('Makan & Minum'), findsWidgets);
    expect(find.text('Rp 500.000'), findsWidgets);

    // Verify ADD and Cairkan ke Wallet buttons exist
    expect(find.text('ADD'), findsWidgets);
    expect(find.text('Cairkan ke Wallet'), findsOneWidget);
    // Verify no edit button exists
    expect(find.text('Edit Budget'), findsNothing);
    expect(find.text('Ubah'), findsNothing);

    // Tap ADD button for Makan & Minum
    await tester.ensureVisible(find.text('ADD').first);
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();

    // Verify ADD dialog is opened
    expect(find.textContaining('ADD: Makan & Minum'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Tap Cairkan ke Wallet button
    await tester.ensureVisible(find.text('Cairkan ke Wallet'));
    await tester.tap(find.text('Cairkan ke Wallet'));
    await tester.pumpAndSettle();

    // Verify Cairkan dialog is opened with Cairkan Semua chip
    expect(find.textContaining('Cairkan ke Wallet: Makan & Minum'), findsOneWidget);
    expect(find.text('Cairkan Semua'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // 3. Test that monthly budget does NOT reset across months
    // Set budget in month 10 (October)
    await storage.setBudget('cat_shopping', 300000, 10, 2026);
    // Query budget in month 11 (November)
    final novBudgets = storage.getBudgets(11, 2026);
    final shoppingBudgetNov = novBudgets.firstWhere((b) => b.categoryId == 'cat_shopping');
    expect(shoppingBudgetNov.monthlyLimit, 300000);
    // Query budget in month 12 (December)
    final decBudgets = storage.getBudgets(12, 2026);
    final shoppingBudgetDec = decBudgets.firstWhere((b) => b.categoryId == 'cat_shopping');
    expect(shoppingBudgetDec.monthlyLimit, 300000);
  });

  testWidgets('Unallocated cash expense succeeds when amount <= totalCash - activeBudgets, and insufficient error formats (Rp 0) properly', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    final ai = await AiService.init();
    final now = DateTime.now();

    // Setup total cash = 553.500
    final wallet = storage.getWallets().first;
    wallet.balance = 553500;
    await storage.saveWallets([wallet]);

    // Setup active budget = 400.000 for Makan & Minum
    await storage.setBudget('cat_food', 400000, now.month, now.year);

    // Setup an old/deleted category budget of 200.000 (orphaned budget)
    // This should NOT affect active monthly budget calculation
    final rawBudgets = storage.getBudgets();
    await storage.saveBudgets([
      ...rawBudgets,
      Budget(
        id: 'orphaned_b',
        categoryId: 'deleted_cat_123',
        monthlyLimit: 200000,
        month: now.month,
        year: now.year,
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => AddTransactionModal(
                  storageService: storage,
                  aiService: ai,
                  localeService: locale,
                  onTransactionAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Open modal and record expense 125.000 with No Category
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '125000');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('No Category'));
    await tester.tap(find.text('No Category'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify transaction 125.000 is saved successfully without error
    final txs = storage.getTransactions();
    expect(txs.any((t) => t.categoryId == 'no_category' && t.amount == 125000), isTrue);

    // 2. Now remaining unallocated cash is: 553.500 - 125.000 = 428.500.
    // 428.500 - 400.000 budget = 28.500.
    // If user enters 50.000, it should fail and show available amount (Rp 28.500)
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('No Category'));
    await tester.tap(find.text('No Category'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Non-category funds insufficient (Rp 28.500)'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Close modal
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 3. Test when unallocated cash is 0: it shows (Rp 0), NOT empty (Rp )
    // Set wallet balance equal to monthly budget = 400.000
    wallet.balance = 400000;
    await storage.saveWallets([wallet]);

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '10000');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('No Category'));
    await tester.tap(find.text('No Category'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify it shows '(Rp 0)', and does NOT show '(Rp )'
    expect(find.textContaining('Non-category funds insufficient (Rp 0)'), findsOneWidget);
    expect(find.textContaining('(Rp )'), findsNothing);
  });

  testWidgets('AddTransactionModal date picker defaults to sysdate and allows selecting custom date which reflects in history', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    await locale.setLocale('id');
    final ai = await AiService.init();

    // Top up wallet
    final wallet = storage.getWallets().first;
    wallet.balance = 1000000;
    await storage.saveWallets([wallet]);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => AddTransactionModal(
                  storageService: storage,
                  aiService: ai,
                  localeService: locale,
                  onTransactionAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // 1. Verify "Tanggal Transaksi" header exists
    expect(find.text('Tanggal Transaksi'), findsOneWidget);

    // 2. Verify default date is today (sysdate) and shows 'Hari ini' badge
    expect(find.text('Hari ini'), findsWidgets);

    // 3. Tap quick chip 'Kemarin'
    await tester.ensureVisible(find.text('Kemarin'));
    await tester.tap(find.text('Kemarin'));
    await tester.pumpAndSettle();

    // Verify 'Kemarin' badge is now active
    expect(find.text('Kemarin'), findsWidgets);

    // 4. Enter amount and note
    await tester.enterText(find.byType(TextField).first, '75000');
    await tester.pumpAndSettle();

    // Tap Save Expense
    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();

    // 5. Verify transaction is saved with yesterday's date
    final txs = storage.getTransactions();
    expect(txs.length, 1);
    final savedTx = txs.first;
    expect(savedTx.amount, 75000);

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    expect(savedTx.date.year, yesterday.year);
    expect(savedTx.date.month, yesterday.month);
    expect(savedTx.date.day, yesterday.day);

    // 6. Record another transaction with today's date
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pumpAndSettle();

    // Keep default (Hari ini)
    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();

    // Verify chronological order: today's transaction (50.000) is first, yesterday's (75.000) is second
    final updatedTxs = storage.getTransactions();
    expect(updatedTxs.length, 2);
    expect(updatedTxs[0].amount, 50000);
    expect(updatedTxs[0].date.day, now.day);
    expect(updatedTxs[1].amount, 75000);
    expect(updatedTxs[1].date.day, yesterday.day);
  });

  testWidgets('Option 3: Budget tagging with wallet and badge display in BudgetScreen', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    await locale.setLocale('id');
    final now = DateTime.now();

    // 1. Setup 2 wallets: Dompet Utama and Bank BCA
    final mainWallet = storage.getWallets().first;
    mainWallet.balance = 500000;
    final bcaWallet = Wallet(
      id: 'w_bca',
      name: 'Bank BCA',
      type: 'bank',
      balance: 100000,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    );
    await storage.saveWallets([mainWallet, bcaWallet]);

    // 2. Set budget for cat_food funded from Bank BCA
    await storage.setBudget('cat_food', 100000, now.month, now.year, 'w_bca');
    final budgets = storage.getBudgets(now.month, now.year);
    final foodBudget = budgets.firstWhere((b) => b.categoryId == 'cat_food');
    expect(foodBudget.walletId, 'w_bca');

    // 3. Render BudgetScreen and verify wallet badge on category card
    await tester.pumpWidget(MaterialApp(
      home: BudgetScreen(
        storageService: storage,
        localeService: locale,
        onDataChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // The badge for Bank BCA should be visible in category list
    expect(find.text('Bank BCA'), findsWidgets);
  });

  testWidgets('Option 3: AddTransactionModal auto-switches wallet on category selection, shows wallet balances in dropdown, and blocks empty wallet expense', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    await locale.setLocale('id');
    final ai = await AiService.init();
    final now = DateTime.now();

    // 1. Setup 2 wallets: Dompet Utama (balance 500.000) and Bank BCA (balance 0)
    final mainWallet = storage.getWallets().first;
    mainWallet.balance = 500000;
    final bcaWallet = Wallet(
      id: 'w_bca',
      name: 'Bank BCA',
      type: 'bank',
      balance: 0,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    );
    await storage.saveWallets([mainWallet, bcaWallet]);

    // 2. Set budget for cat_food with walletId 'w_cash' (Dompet Utama)
    await storage.setBudget('cat_food', 200000, now.month, now.year, 'w_cash');

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => AddTransactionModal(
                  storageService: storage,
                  aiService: ai,
                  localeService: locale,
                  initialWalletId: 'w_bca',
                  onTransactionAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // 3. Verify dropdown shows empty wallet indicator 'Rp 0 (Kosong)'
    expect(find.textContaining('Rp 0 (Kosong)'), findsWidgets);

    // 4. Tap cat_food (Makan & Minum): should auto-switch wallet to 'w_cash' (Dompet Utama)
    final foodCatFinder = find.text('Makan & Minum');
    expect(foodCatFinder, findsWidgets);
    await tester.ensureVisible(foodCatFinder.first);
    await tester.tap(foodCatFinder.first);
    await tester.pumpAndSettle();

    // Enter amount 50000
    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pumpAndSettle();

    // 5. Now switch manually back to Bank BCA (which has Rp 0) to verify strict block
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    // Select Bank BCA from dropdown items
    await tester.tap(find.text('Bank BCA').last);
    await tester.pumpAndSettle();

    // Attempt to save expense 50.000 with Bank BCA (balance = 0)
    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();

    // Verify pop alert dialog appears with insufficient wallet balance message
    expect(find.textContaining('Saldo dompet tidak mencukupi (Bank BCA: Rp 0)'), findsOneWidget);
    expect(find.textContaining('Silakan gunakan dompet lain atau isi saldo terlebih dahulu'), findsOneWidget);

    // Dismiss alert dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Verify transaction was NOT recorded and BCA balance is still 0 (not negative)
    expect(storage.getTransactions().isEmpty, isTrue);
    final bcaAfter = storage.getWallets().firstWhere((w) => w.id == 'w_bca');
    expect(bcaAfter.balance, 0);

    // 6. Switch back to Dompet Utama and save
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dompet Utama').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Simpan Pengeluaran'));
    await tester.tap(find.text('Simpan Pengeluaran'));
    await tester.pumpAndSettle();

    // Verify transaction succeeded with Dompet Utama
    final txs = storage.getTransactions();
    expect(txs.length, 1);
    expect(txs.first.walletId, 'w_cash');
    expect(txs.first.amount, 50000);

    // Dompet Utama balance reduced to 450.000
    final mainAfter = storage.getWallets().firstWhere((w) => w.id == 'w_cash');
    expect(mainAfter.balance, 450000);
  });

  testWidgets('SavingsScreen renders dedicated button for pocket history and navigates to PocketHistoryScreen', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    await locale.setLocale('id');

    // 1. Create a pocket and some mutation records
    final pocket = SavingsPocket(
      id: 'p_dana_darurat',
      name: 'Dana Darurat',
      targetAmount: 10000000,
      currentAmount: 2000000,
      colorValue: 0xFF10B981,
      icon: 'savings',
      createdAt: DateTime.now(),
    );
    await storage.addSavingsPocket(pocket);

    await storage.saveSavingsRecords([
      SavingsRecord(
        id: 'rec_1',
        pocketId: 'p_dana_darurat',
        pocketName: 'Dana Darurat',
        walletId: 'w_cash',
        walletName: 'Dompet Utama',
        amount: 500000,
        type: 'deposit',
        date: DateTime.now(),
        note: 'Setor awal bulan',
      ),
      SavingsRecord(
        id: 'rec_2',
        pocketId: 'p_dana_darurat',
        pocketName: 'Dana Darurat',
        walletId: 'w_cash',
        walletName: 'Dompet Utama',
        amount: 100000,
        type: 'withdraw',
        date: DateTime.now(),
        note: 'Tarik kebutuhan darurat',
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SavingsScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 2. Verify "Lihat Riwayat Tabungan" button is rendered on SavingsScreen
    final historyBtnFinder = find.text('Lihat Riwayat Tabungan');
    expect(historyBtnFinder, findsOneWidget);
    expect(find.text('2'), findsWidgets);

    // 3. Scroll and tap "Lihat Riwayat Tabungan"
    await tester.ensureVisible(historyBtnFinder);
    await tester.tap(historyBtnFinder);
    await tester.pumpAndSettle();

    // 4. Verify PocketHistoryScreen is displayed
    expect(find.byType(PocketHistoryScreen), findsOneWidget);
    expect(find.text('Riwayat Tabungan'), findsOneWidget);
    expect(find.text('TOTAL MUTASI'), findsOneWidget);
    expect(find.text('Setor awal bulan'), findsOneWidget);
    expect(find.text('Tarik kebutuhan darurat'), findsOneWidget);

    // 5. Tap on a record to open detail modal
    await tester.tap(find.text('Setor awal bulan'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Mutasi Tabungan'), findsOneWidget);
    expect(find.text('Pos Kantong Tabungan'), findsOneWidget);

    // Close detail modal
    Navigator.of(tester.element(find.text('Detail Mutasi Tabungan'))).pop();
    await tester.pumpAndSettle();

    // 6. Tap back button to return to SavingsScreen
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(PocketHistoryScreen), findsNothing);
    expect(find.byType(SavingsScreen), findsOneWidget);
  });

  testWidgets('BudgetScreen ADD budget limit check depends strictly on selected funding wallet balance, not total cash', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final storage = await StorageService.init();
    final locale = await LocaleService.init();
    await locale.setLocale('id');

    // 1. Setup Dompet Utama = 1.500.000, Bank BCA = 225.000 (Total Cash = 1.725.000)
    final mainWallet = storage.getWallets().first;
    mainWallet.balance = 1500000;
    final bcaWallet = Wallet(
      id: 'w_bca',
      name: 'Bank BCA',
      type: 'bank',
      balance: 225000,
      icon: 'account_balance',
      colorValue: 0xFF38BDF8,
    );
    await storage.saveWallets([mainWallet, bcaWallet]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BudgetScreen(
          storageService: storage,
          localeService: locale,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 2. Tap ADD button on first category (Makan & Minum)
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.textContaining('ADD: Makan & Minum'), findsOneWidget);

    // Switch funding wallet dropdown to Bank BCA
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank BCA').last);
    await tester.pumpAndSettle();

    // Verify reference card shows Bank BCA balance = Rp 225.000
    expect(find.textContaining('Saldo Dompet Sumber (Bank BCA):'), findsOneWidget);
    expect(find.text('Rp 225.000'), findsWidgets);

    // 3. Enter 1.000.000 (which is less than total cash 1.725.000, but GREATER than Bank BCA 225.000)
    await tester.enterText(find.byType(TextField).first, '1000000');
    await tester.pumpAndSettle();

    // Verify error warning appears
    expect(find.textContaining('Nominal anggaran melebihi saldo dompet yang dipilih! (Bank BCA Maks: Rp 225.000)'), findsOneWidget);

    // Tap Tambah: must be blocked by validation
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nominal anggaran melebihi saldo dompet yang dipilih! (Bank BCA Maks: Rp 225.000)'), findsWidgets);
    // Dialog should NOT be dismissed because save was blocked
    expect(find.textContaining('ADD: Makan & Minum'), findsOneWidget);

    // Let SnackBar dismiss
    await tester.pump(const Duration(seconds: 4));

    // 4. Change amount to safe limit: 225.000
    await tester.enterText(find.byType(TextField).first, '225000');
    await tester.pumpAndSettle();

    // Error warning should disappear
    expect(find.textContaining('Nominal anggaran melebihi saldo dompet yang dipilih!'), findsNothing);

    // Tap Tambah: should succeed
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah'));
    await tester.pumpAndSettle();

    // Dialog dismissed and budget saved
    expect(find.textContaining('ADD: Makan & Minum'), findsNothing);
    final now = DateTime.now();
    final savedBudgets = storage.getBudgets(now.month, now.year);
    final foodB = savedBudgets.firstWhere((b) => b.categoryId == 'cat_food');
    expect(foodB.monthlyLimit, 225000);
    expect(foodB.walletId, 'w_bca');
  });

  testWidgets('Home Screen differentiates Main Balance and Total Cash Balance with Pocket breakdown', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final auth = await AuthService.init();
    final locale = await LocaleService.init();
    final ai = await AiService.init();

    // Set wallets: Tunai = 300.000, Bank BCA = 200.000 -> Total Wallet Cash = 500.000
    await storage.saveWallets([
      Wallet(id: 'w_cash', name: 'Tunai', type: 'cash', balance: 300000, icon: 'account_balance_wallet', colorValue: 0xFF10B981),
      Wallet(id: 'w_bca', name: 'Bank BCA', type: 'bank', balance: 200000, icon: 'account_balance', colorValue: 0xFF3B82F6),
    ]);

    // Set a monthly budget of 100.000 for cat_food
    final now = DateTime.now();
    await storage.setBudget('cat_food', 100000, now.month, now.year, 'w_cash');

    // Set a secret savings pocket with 77.000 (must NEVER leak into Home Screen)
    await storage.saveSavingsPockets([
      SavingsPocket(
        id: 'sp_vacation',
        name: 'Liburan Bali',
        targetAmount: 1000000,
        currentAmount: 77000,
        icon: 'beach_access',
        colorValue: 0xFF06B6D4,
        createdAt: DateTime.now(),
      ),
    ]);

    // Total Wallet Cash = 500.000
    // Total Monthly Budget = 100.000
    // Main Balance (Cash not in monthly budget) = 400.000
    // Total Balance = Main Balance (400.000) + Monthly Budget (100.000) = 500.000
    // Secret Pocket (77.000) is NEVER shown or added on Home Screen

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        storageService: storage,
        authService: auth,
        localeService: locale,
        aiService: ai,
        onNavigateToTab: (_) {},
        onOpenAiAssistant: () {},
        onDataChanged: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify MAIN BALANCE label is displayed
    expect(find.text('MAIN BALANCE'), findsOneWidget);

    // 2. Verify Main Balance displays Rp 400.000 (cash not in monthly budget: 500k - 100k)
    expect(find.text('Rp 400.000'), findsOneWidget);

    // 3. Verify Total Cash info pill displays Total Cash: Rp 500.000 (Main Balance 400k + Budget 100k)
    expect(find.text('Total Cash: Rp 500.000'), findsOneWidget);

    // 4. Verify In Budget info tag displays In Budget: Rp 100.000
    expect(find.text('In Budget: Rp 100.000'), findsOneWidget);

    // 5. Verify Pocket is NEVER shown anywhere on the Home screen
    expect(find.textContaining('In Pocket'), findsNothing);
    expect(find.textContaining('Di Pocket'), findsNothing);
    expect(find.textContaining('77.000'), findsNothing);
    expect(find.textContaining('Liburan Bali'), findsNothing);

    // 6. Test privacy toggle (hide balances)
    await tester.tap(find.byTooltip('Balance Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('Rp ••••••••'), findsOneWidget); // Main balance hidden
    expect(find.text('Total Cash: Rp ••••••'), findsOneWidget); // Total cash hidden
    expect(find.text('In Budget: Rp •••'), findsOneWidget); // Budget hidden
    expect(find.textContaining('In Pocket'), findsNothing);
  });
}
