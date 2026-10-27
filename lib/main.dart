import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'widgets/passcode_keypad.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IriTotApp());
}

class IriTotApp extends StatefulWidget {
  final StorageService? storageService;
  final AiService? aiService;
  final AuthService? authService;
  final LocaleService? localeService;
  final bool enableSplash;
  final Duration splashDuration;

  const IriTotApp({
    super.key,
    this.storageService,
    this.aiService,
    this.authService,
    this.localeService,
    this.enableSplash = true,
    this.splashDuration = const Duration(milliseconds: 1800),
  });

  @override
  State<IriTotApp> createState() => _IriTotAppState();
}

class _IriTotAppState extends State<IriTotApp> with WidgetsBindingObserver {
  late bool _showSplash;
  bool _isLoggedIn = false;
  String? _sessionTimeoutMessage;
  String? _initErrorMessage;

  StorageService? _storageService;
  AiService? _aiService;
  AuthService? _authService;
  late LocaleService _localeService;
  bool _isInitialized = false;
  bool _splashDurationFinished = false;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.enableSplash;
    _localeService = widget.localeService ?? LocaleService();
    WidgetsBinding.instance.addObserver(this);

    if (widget.storageService != null &&
        widget.aiService != null &&
        widget.authService != null &&
        widget.localeService != null) {
      _storageService = widget.storageService;
      _aiService = widget.aiService;
      _authService = widget.authService;
      _isInitialized = true;
      _evaluateInitialAuthSession();
    } else {
      _bootstrapServicesAsync();
    }
  }

  void _evaluateInitialAuthSession() {
    final auth = _authService;
    if (auth == null) return;

    if (auth.isSessionExpired()) {
      auth.lockSessionDueToTimeout();
      _isLoggedIn = false;
      _sessionTimeoutMessage = _localeService.t('sessionTimeoutMsg');
    } else {
      _isLoggedIn = auth.isLoggedIn();
      if (_isLoggedIn) {
        auth.updateLastActiveTimestamp();
      }
    }
  }

  Future<void> _bootstrapServicesAsync() async {
    try {
      try {
        await Future.wait([
          initializeDateFormatting('en_US', null),
          initializeDateFormatting('id_ID', null),
        ]);
      } catch (e) {
        debugPrint('Locale date formatting warning: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      final storage = await StorageService.init(prefs);
      final ai = await AiService.init(prefs);
      final auth = await AuthService.init(prefs);
      _localeService.updatePrefs(prefs);

      if (mounted) {
        setState(() {
          _storageService = storage;
          _aiService = ai;
          _authService = auth;
          _isInitialized = true;
          _evaluateInitialAuthSession();

          if (_splashDurationFinished && _showSplash) {
            _showSplash = false;
          }
        });
      }
    } catch (e, stack) {
      debugPrint('Fatal error initializing IriTot: $e\n$stack');
      if (mounted) {
        setState(() {
          _initErrorMessage = e.toString();
        });
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
    final auth = _authService;
    if (auth == null || !_isLoggedIn) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      auth.updateLastActiveTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      if (auth.isSessionExpired()) {
        auth.lockSessionDueToTimeout();
        setState(() {
          _isLoggedIn = false;
          _sessionTimeoutMessage = _localeService.t('sessionTimeoutMsg');
        });
      } else {
        auth.updateLastActiveTimestamp();
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
    await _authService?.logout();
    setState(() {
      _isLoggedIn = false;
      _sessionTimeoutMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _localeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'IRITOT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: _buildHomeWidget(),
        );
      },
    );
  }

  Widget _buildHomeWidget() {
    if (_initErrorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.coralRose, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Notice',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _initErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initErrorMessage = null;
                    });
                    _bootstrapServicesAsync();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showSplash) {
      return SplashScreen(
        localeService: _localeService,
        duration: widget.splashDuration,
        onFinish: () {
          _splashDurationFinished = true;
          if (_isInitialized) {
            setState(() {
              _showSplash = false;
            });
          }
        },
      );
    }

    if (!_isInitialized || _storageService == null || _aiService == null || _authService == null) {
      return SplashScreen(
        localeService: _localeService,
        duration: const Duration(milliseconds: 300),
        onFinish: () {},
      );
    }

    if (_isLoggedIn) {
      return MainNavigationScaffold(
        storageService: _storageService!,
        aiService: _aiService!,
        authService: _authService!,
        localeService: _localeService,
        onLogout: _handleLogout,
      );
    }

    return LoginScreen(
      authService: _authService!,
      localeService: _localeService,
      initialErrorMessage: _sessionTimeoutMessage,
      onLoginSuccess: _handleLoginSuccess,
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
  final int _homeTabIndex = 0;
  int _homeResetTick = 0;

  void _onDataChanged() {
    widget.authService.updateLastActiveTimestamp();
    setState(() {});
  }

  /// Asks for the 6-digit security PIN before the Pocket tab opens.
  Future<bool> _confirmPocketAccess() async {
    final t = widget.localeService.t;
    final keypadKey = GlobalKey<PasscodeKeypadState>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.borderDark, width: 1.2),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                PasscodeKeypad(
                  key: keypadKey,
                  pinLength: 6,
                  title: t('verifyPinTitle'),
                  subtitle: t('verifyPinDesc'),
                  cancelLabel: t('cancel'),
                  onCancel: () => Navigator.pop(bottomSheetCtx, false),
                  onPinComplete: (pin) {
                    if (widget.authService.verifyPin(pin)) {
                      Navigator.pop(bottomSheetCtx, true);
                    } else {
                      keypadKey.currentState?.triggerError(t('verifyPinWrong'));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  void _onNavTap(int index) async {
    widget.authService.updateLastActiveTimestamp();
    if (index == 2) {
      _openAddModal();
      return;
    }
    if (index == 0) {
      // Home always lands on the Spending tab
      setState(() {
        _currentIndex = 0;
        _homeResetTick++;
      });
      return;
    }
    if (index == 1 && _currentIndex != 1) {
      final granted = await _confirmPocketAccess();
      if (!granted || !mounted) return;
    }
    setState(() => _currentIndex = index);
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(
        storageService: widget.storageService,
        aiService: widget.aiService,
        localeService: widget.localeService,
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
        localeService: widget.localeService,
        onDataChanged: _onDataChanged,
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
        authService: widget.authService,
        localeService: widget.localeService,
        onDataChanged: _onDataChanged,
        onNavigateToTab: _onNavTap,
        onOpenAiAssistant: _openAiAssistant,
        initialTabIndex: _homeTabIndex,
        resetTick: _homeResetTick,
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
        onDataChanged: _onDataChanged,
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
          currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
          onTap: _onNavTap,
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
