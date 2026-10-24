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

    // 1. Verify Login Screen elements (Default English PIN Login)
    expect(find.text('Sign In with PIN'), findsOneWidget);
    expect(find.text('Sign In to IRITOT'), findsOneWidget);
    expect(find.text('Isi Default'), findsNothing);
    expect(find.textContaining('Default: NewUser'), findsNothing);

    // 2. Enter default PIN (0000) into PIN text field
    await tester.enterText(find.byType(TextField).first, '0000');

    // 3. Tap Login Button
    await tester.tap(find.text('Sign In to IRITOT'));
    await tester.pumpAndSettle();

    // 4. Verify Home Screen elements after successful login
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

    // 5a. Pocket requires the PIN: a wrong PIN is rejected
    expect(find.text('Verify PIN'), findsOneWidget);
    expect(find.text('TOTAL SAVINGS'), findsNothing);
    await tester.enterText(find.byType(TextField).last, '9999');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN.'), findsOneWidget);

    // 5b. The correct PIN opens Pocket
    await tester.enterText(find.byType(TextField).last, '0000');
    await tester.tap(find.text('Verify'));
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
    expect(authService.getPin(), '0000');
    expect(authService.getDisplayName(), 'NewUser');
    expect(authService.isLoggedIn(), false);

    // Login test with wrong PIN
    final wrongLogin = await authService.login('9999');
    expect(wrongLogin, false);
    expect(authService.isLoggedIn(), false);

    // Login test with correct PIN
    final correctLogin = await authService.login('0000');
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
      oldPin: '9999',
      newPin: '1234',
    );
    expect(failOldPin['success'], false);
    expect(failOldPin['message'], contains('PIN lama salah'));

    // Change PIN: test failure with short PIN (< 4 digits)
    final failShortPin = await authService.changePin(
      oldPin: '0000',
      newPin: '12',
    );
    expect(failShortPin['success'], false);
    expect(failShortPin['message'], contains('minimal 4 angka'));

    // Change PIN: test failure with non-digits
    final failLetterPin = await authService.changePin(
      oldPin: '0000',
      newPin: 'abcd',
    );
    expect(failLetterPin['success'], false);
    expect(failLetterPin['message'], contains('hanya boleh berisi angka'));

    // Change PIN: test success with valid old and new PIN
    final successChange = await authService.changePin(
      oldPin: '0000',
      newPin: '1234',
    );
    expect(successChange['success'], true);
    expect(authService.getPin(), '1234');

    // Verify login with updated PIN
    final oldLoginAttempt = await authService.login('0000');
    expect(oldLoginAttempt, false);

    final newLoginAttempt = await authService.login('1234');
    expect(newLoginAttempt, true);

    // Test logout
    await authService.logout();
    expect(authService.isLoggedIn(), false);
  });

  test('AuthService updateProfile supports changing PIN and display name simultaneously', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final authService = await AuthService.init();
    expect(authService.getPin(), '0000');
    expect(authService.getDisplayName(), 'NewUser');

    // Update display name and PIN together
    final updateResult = await authService.updateProfile(
      newDisplayName: 'Aji Pocket',
      oldPin: '0000',
      newPin: '4321',
    );
    expect(updateResult['success'], true);
    expect(authService.getDisplayName(), 'Aji Pocket');
    expect(authService.getPin(), '4321');

    // Verify login works with new PIN
    final loginSuccess = await authService.login('4321');
    expect(loginSuccess, true);
    expect(authService.isLoggedIn(), true);

    // Logout
    await authService.logout();
    expect(authService.isLoggedIn(), false);
  });

  testWidgets('LoginScreen renders PIN input and logs in successfully', (tester) async {
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

    // Verify exactly one PIN TextField
    expect(find.byType(TextField), findsOneWidget);

    // Enter wrong PIN
    await tester.enterText(find.byType(TextField), '8888');
    await tester.tap(find.text('Sign In to IRITOT'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);
    expect(loginSuccessCalled, false);

    // Enter correct default PIN (0000)
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Sign In to IRITOT'));
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
    expect(localeService.t('loginTitle'), 'Sign In with PIN');

    // Switch to Indonesian
    await localeService.setLocale('id');
    expect(localeService.currentLocale, 'id');
    expect(localeService.isEnglish, false);
    expect(localeService.isIndonesian, true);
    expect(localeService.t('navHome'), 'Beranda');
    expect(localeService.t('loginTitle'), 'Masuk dengan PIN');

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
    await authService.login('0000');
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

    // Verify smooth transition to LoginScreen with PIN
    expect(find.text('Sign In with PIN'), findsOneWidget);
  });
}
