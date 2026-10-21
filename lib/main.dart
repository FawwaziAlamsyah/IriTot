import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/storage_service.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/locale_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/add_transaction_modal.dart';
import 'screens/ai_assistant_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('id_ID', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.init();
  final aiService = await AiService.init();
  final authService = await AuthService.init();
  final localeService = await LocaleService.init();

  runApp(IriTotApp(
    storageService: storageService,
    aiService: aiService,
    authService: authService,
    localeService: localeService,
  ));
}

class IriTotApp extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final AuthService authService;
  final LocaleService localeService;
  final bool enableSplash;
  final Duration splashDuration;

  const IriTotApp({
    super.key,
    required this.storageService,
    required this.aiService,
    required this.authService,
    required this.localeService,
    this.enableSplash = true,
    this.splashDuration = const Duration(milliseconds: 1800),
  });

  @override
  State<IriTotApp> createState() => _IriTotAppState();
}

class _IriTotAppState extends State<IriTotApp> with WidgetsBindingObserver {
  late bool _showSplash;
  late bool _isLoggedIn;
  String? _sessionTimeoutMessage;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.enableSplash;
    WidgetsBinding.instance.addObserver(this);
    if (widget.authService.isSessionExpired()) {
      widget.authService.lockSessionDueToTimeout();
      _isLoggedIn = false;
      _sessionTimeoutMessage = widget.localeService.t('sessionTimeoutMsg');
    } else {
      _isLoggedIn = widget.authService.isLoggedIn();
      if (_isLoggedIn) {
        widget.authService.updateLastActiveTimestamp();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoggedIn) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // User minimized the app or switched away
      widget.authService.updateLastActiveTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      // User came back to the app
      if (widget.authService.isSessionExpired()) {
        widget.authService.lockSessionDueToTimeout();
        setState(() {
          _isLoggedIn = false;
          _sessionTimeoutMessage = widget.localeService.t('sessionTimeoutMsg');
        });
      } else {
        widget.authService.updateLastActiveTimestamp();
      }
    }
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
      _sessionTimeoutMessage = null;
    });
  }

  void _handleLogout() async {
    await widget.authService.logout();
    setState(() {
      _isLoggedIn = false;
      _sessionTimeoutMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.localeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'IRITOT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: _showSplash
              ? SplashScreen(
                  localeService: widget.localeService,
                  duration: widget.splashDuration,
                  onFinish: () {
                    setState(() {
                      _showSplash = false;
                    });
                  },
                )
              : (_isLoggedIn
                  ? MainNavigationScaffold(
                      storageService: widget.storageService,
                      aiService: widget.aiService,
                      authService: widget.authService,
                      localeService: widget.localeService,
                      onLogout: _handleLogout,
                    )
                  : LoginScreen(
                      authService: widget.authService,
                      localeService: widget.localeService,
                      initialErrorMessage: _sessionTimeoutMessage,
                      onLoginSuccess: _handleLoginSuccess,
                    )),
        );
      },
    );
  }
}

class MainNavigationScaffold extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final AuthService authService;
  final LocaleService localeService;
  final VoidCallback onLogout;

  const MainNavigationScaffold({
    super.key,
    required this.storageService,
    required this.aiService,
    required this.authService,
    required this.localeService,
    required this.onLogout,
  });

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  void _onDataChanged() {
    widget.authService.updateLastActiveTimestamp();
    setState(() {});
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(
        storageService: widget.storageService,
        aiService: widget.aiService,
        onTransactionAdded: _onDataChanged,
      ),
    );
  }

  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiAssistantSheet(
        storageService: widget.storageService,
        aiService: widget.aiService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeService.t;

    final List<Widget> screens = [
      HomeScreen(
        storageService: widget.storageService,
        aiService: widget.aiService,
        localeService: widget.localeService,
        onDataChanged: _onDataChanged,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
        onOpenAiAssistant: _openAiAssistant,
      ),
      SavingsScreen(
        storageService: widget.storageService,
        localeService: widget.localeService,
        onDataChanged: _onDataChanged,
      ),
      // Dummy index 2 untuk posisi Floating Action Button (+)
      const SizedBox.shrink(),
      ReportsScreen(
        storageService: widget.storageService,
        localeService: widget.localeService,
      ),
      SettingsScreen(
        storageService: widget.storageService,
        aiService: widget.aiService,
        authService: widget.authService,
        localeService: widget.localeService,
        onDataChanged: _onDataChanged,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddModal,
        backgroundColor: AppTheme.emeraldGreen,
        foregroundColor: Colors.black,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28, color: Colors.black),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            widget.authService.updateLastActiveTimestamp();
            if (index == 2) {
              _openAddModal();
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_filled),
              label: t('navHome'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.savings_outlined),
              activeIcon: const Icon(Icons.savings),
              label: t('navSavings'),
            ),
            BottomNavigationBarItem(
              icon: const SizedBox(width: 24, height: 24),
              label: t('navLog'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart_rounded),
              label: t('navReports'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              label: t('navSettings'),
            ),
          ],
        ),
      ),
    );
  }
}
