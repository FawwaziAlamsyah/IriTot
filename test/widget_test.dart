import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:iritot/main.dart';
import 'package:iritot/services/storage_service.dart';
import 'package:iritot/services/ai_service.dart';
import 'package:iritot/services/auth_service.dart';
import 'package:iritot/services/locale_service.dart';
import 'package:iritot/screens/splash_screen.dart';
import 'package:iritot/screens/login_screen.dart';

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
    expect(find.text('TOTAL CASH BALANCE'), findsOneWidget);
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
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
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
}
