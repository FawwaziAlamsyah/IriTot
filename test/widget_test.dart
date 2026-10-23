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

    // 1. Verify Login Screen elements (Default English, Clean UI without default buttons)
    expect(find.text('Sign In to Your Account'), findsOneWidget);
    expect(find.text('Sign In to IRITOT'), findsOneWidget);
    expect(find.text('Isi Default'), findsNothing);
    expect(find.textContaining('Default: usertest'), findsNothing);

    // 2. Enter credentials into empty text fields
    await tester.enterText(find.byType(TextField).at(0), 'usertest');
    await tester.enterText(find.byType(TextField).at(1), 'iritot123');

    // 3. Tap Login Button
    await tester.tap(find.text('Sign In to IRITOT'));
    await tester.pumpAndSettle();

    // 4. Verify Home Screen elements after successful login
    expect(find.text('IRITOT'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('TOTAL CASH BALANCE'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('SAVINGS & POCKETS'), findsNothing);

    // 5. Verify Pocket tab item exists and tap it
    expect(find.text('Pocket'), findsNWidgets(2));
    await tester.tap(find.text('Pocket').first);
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
    expect(authService.getUsername(), 'usertest');
    expect(authService.isLoggedIn(), false);

    // Login test with wrong password
    final wrongLogin = await authService.login('usertest', 'wrongpass');
    expect(wrongLogin, false);
    expect(authService.isLoggedIn(), false);

    // Login test with correct credentials
    final correctLogin = await authService.login('usertest', 'iritot123');
    expect(correctLogin, true);
    expect(authService.isLoggedIn(), true);

    // Change credentials: test failure with incorrect old username
    final failOldUser = await authService.changeCredentials(
      oldUsername: 'wronguser',
      oldPassword: 'iritot123',
      newUsername: 'ajifinance',
      newPassword: 'newpassword123',
    );
    expect(failOldUser['success'], false);
    expect(failOldUser['message'], contains('Username lama tidak sesuai'));

    // Change credentials: test failure with incorrect old password
    final failOldPass = await authService.changeCredentials(
      oldUsername: 'usertest',
      oldPassword: 'wrongoldpassword',
      newUsername: 'ajifinance',
      newPassword: 'newpassword123',
    );
    expect(failOldPass['success'], false);
    expect(failOldPass['message'], contains('Password lama salah'));

    // Change credentials: test failure with short password (< 4 chars)
    final failShortPass = await authService.changeCredentials(
      oldUsername: 'usertest',
      oldPassword: 'iritot123',
      newUsername: 'ajifinance',
      newPassword: '12',
    );
    expect(failShortPass['success'], false);
    expect(failShortPass['message'], contains('minimal 4 karakter'));

    // Change credentials: test success with valid old and new credentials
    final successChange = await authService.changeCredentials(
      oldUsername: 'usertest',
      oldPassword: 'iritot123',
      newUsername: 'ajifinance',
      newPassword: 'newpassword123',
    );
    expect(successChange['success'], true);
    expect(authService.getUsername(), 'ajifinance');

    // Verify login with updated credentials
    final oldLoginAttempt = await authService.login('usertest', 'iritot123');
    expect(oldLoginAttempt, false);

    final newLoginAttempt = await authService.login('ajifinance', 'newpassword123');
    expect(newLoginAttempt, true);

    // Test logout
    await authService.logout();
    expect(authService.isLoggedIn(), false);
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
    expect(localeService.t('loginTitle'), 'Sign In to Your Account');

    // Switch to Indonesian
    await localeService.setLocale('id');
    expect(localeService.currentLocale, 'id');
    expect(localeService.isEnglish, false);
    expect(localeService.isIndonesian, true);
    expect(localeService.t('navHome'), 'Beranda');
    expect(localeService.t('loginTitle'), 'Masuk ke Akun Anda');

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
    await authService.login('usertest', 'iritot123');
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

    // Verify smooth transition to LoginScreen
    expect(find.text('Sign In to Your Account'), findsOneWidget);
  });
}
