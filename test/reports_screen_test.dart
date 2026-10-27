import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iritot/services/storage_service.dart';
import 'package:iritot/services/locale_service.dart';
import 'package:iritot/models/transaction_item.dart';
import 'package:iritot/screens/reports_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ReportsScreen renders financial reports and allows viewing all past history', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storageService = await StorageService.init();
    final localeService = await LocaleService.init();

    final now = DateTime.now();
    final pastDate = DateTime(now.year - 1, 5, 15); // A transaction from last year!

    // Add current month expense
    await storageService.addTransaction(TransactionItem(
      id: 'tx_current_month',
      walletId: 'w_cash',
      categoryId: 'cat_food',
      amount: 45000,
      type: 'expense',
      note: 'Makan Siang Hari Ini',
      date: now,
    ));

    // Add current month income
    await storageService.addTransaction(TransactionItem(
      id: 'tx_income_current',
      walletId: 'w_cash',
      categoryId: 'cat_salary',
      amount: 1500000,
      type: 'income',
      note: 'Gaji Freelance',
      date: now,
    ));

    // Add past year expense
    await storageService.addTransaction(TransactionItem(
      id: 'tx_past_year',
      walletId: 'w_cash',
      categoryId: 'cat_shopping',
      amount: 320000,
      type: 'expense',
      note: 'Beli Sepatu Lama',
      date: pastDate,
    ));

    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        storageService: storageService,
        localeService: localeService,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. In default mode (This Month), current month transactions are present
    expect(find.text('Financial Reports'), findsOneWidget);
    expect(find.text('Makan Siang Hari Ini'), findsOneWidget);
    expect(find.text('Gaji Freelance'), findsOneWidget);
    // Past year transaction should NOT appear in "This Month"
    expect(find.text('Beli Sepatu Lama'), findsNothing);

    // 2. Tap "All Time" period pill to view all past history
    final allTimeFinder = find.text('All Time');
    expect(allTimeFinder, findsOneWidget);
    await tester.tap(allTimeFinder);
    await tester.pumpAndSettle();

    // Now all 3 transactions must appear!
    expect(find.text('Beli Sepatu Lama'), findsOneWidget);
    expect(find.text('Makan Siang Hari Ini'), findsOneWidget);
    expect(find.text('Gaji Freelance'), findsOneWidget);

    // 3. Test Search filtering
    final searchFinder = find.byType(TextField);
    expect(searchFinder, findsOneWidget);
    await tester.enterText(searchFinder, 'sepatu');
    await tester.pumpAndSettle();

    // Only 'Beli Sepatu Lama' should remain visible
    expect(find.text('Beli Sepatu Lama'), findsOneWidget);
    expect(find.text('Makan Siang Hari Ini'), findsNothing);
    expect(find.text('Gaji Freelance'), findsNothing);

    // Clear search
    await tester.enterText(searchFinder, '');
    await tester.pumpAndSettle();
    expect(find.text('Makan Siang Hari Ini'), findsOneWidget);

    // 4. Test Type filter (Income vs Expense)
    // Tap Type filter dropdown (shows 'All')
    final filterPillFinder = find.text('All');
    expect(filterPillFinder, findsOneWidget);
    await tester.tap(filterPillFinder);
    await tester.pumpAndSettle();

    // Choose 'Income' from bottom sheet
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();

    // Only Income transaction should be visible in transaction list
    expect(find.text('Gaji Freelance'), findsOneWidget);
    expect(find.text('Makan Siang Hari Ini'), findsNothing);
    expect(find.text('Beli Sepatu Lama'), findsNothing);

    // 5. Test Chart toggle (Income vs Expense)
    // Switch chart to Income
    await tester.tap(find.byKey(const Key('chart_toggle_income')));
    await tester.pumpAndSettle();
    expect(find.text('INCOME BY CATEGORY'), findsOneWidget);
  });

  testWidgets('ReportsScreen transaction detail modal opens and handles deletion', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storageService = await StorageService.init();
    final localeService = await LocaleService.init();

    final now = DateTime.now();
    await storageService.addTransaction(TransactionItem(
      id: 'tx_to_delete',
      walletId: 'w_cash',
      categoryId: 'cat_food',
      amount: 25000,
      type: 'expense',
      note: 'Kopi Kenangan',
      date: now,
    ));

    bool dataChangedCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        storageService: storageService,
        localeService: localeService,
        onDataChanged: () => dataChangedCalled = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kopi Kenangan'), findsOneWidget);

    // Tap on the transaction to open details
    await tester.tap(find.text('Kopi Kenangan'));
    await tester.pumpAndSettle();

    // Detail modal should be displayed
    expect(find.text('Transaction Details'), findsOneWidget);
    expect(find.text('Delete Transaction'), findsOneWidget);

    // Tap delete button in modal
    await tester.tap(find.text('Delete Transaction'));
    await tester.pumpAndSettle();

    // Confirm dialog appears: tap 'Delete'
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Should have deleted transaction from storage and called callback
    expect(dataChangedCalled, isTrue);
    expect(find.text('Kopi Kenangan'), findsNothing);
    expect(storageService.getTransactions().where((t) => t.id == 'tx_to_delete').isEmpty, isTrue);
  });

  testWidgets('ReportsScreen monthly filter quick-bar and modal allows filtering per month', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final storageService = await StorageService.init();
    final localeService = await LocaleService.init();

    final now = DateTime.now();
    final augustDate = DateTime(now.year, 8, 15);
    final septemberDate = DateTime(now.year, 9, 10);

    await storageService.addTransaction(TransactionItem(
      id: 'tx_august',
      walletId: 'w_cash',
      categoryId: 'cat_food',
      amount: 75000,
      type: 'expense',
      note: 'Makan di Bulan Agustus',
      date: augustDate,
    ));

    await storageService.addTransaction(TransactionItem(
      id: 'tx_september',
      walletId: 'w_cash',
      categoryId: 'cat_shopping',
      amount: 150000,
      type: 'expense',
      note: 'Belanja di Bulan September',
      date: septemberDate,
    ));

    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        storageService: storageService,
        localeService: localeService,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Initially on current month, so August/September transactions are not visible
    expect(find.text('Makan di Bulan Agustus'), findsNothing);
    expect(find.text('Belanja di Bulan September'), findsNothing);

    // 2. Tap month filter button in the filter bar
    final monthFilterBtn = find.byKey(const Key('filter_btn_month'));
    expect(monthFilterBtn, findsOneWidget);
    await tester.tap(monthFilterBtn);
    await tester.pumpAndSettle();

    // 3. Month picker sheet appears, select August
    expect(find.text('August'), findsOneWidget);
    await tester.tap(find.text('August'));
    await tester.pumpAndSettle();

    // Now August transaction is visible, but September is not
    expect(find.text('Makan di Bulan Agustus'), findsOneWidget);
    expect(find.text('Belanja di Bulan September'), findsNothing);

    // 4. Test tapping month chip directly in the horizontal quick-bar (e.g. 'Sep')
    final sepChipFinder = find.text('Sep');
    expect(sepChipFinder, findsOneWidget);
    await tester.tap(sepChipFinder);
    await tester.pumpAndSettle();

    // Now September transaction is visible, and August is not
    expect(find.text('Belanja di Bulan September'), findsOneWidget);
    expect(find.text('Makan di Bulan Agustus'), findsNothing);
  });
}
