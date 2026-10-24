import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';
import '../widgets/passcode_keypad.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final LocaleService localeService;
  final String? initialErrorMessage;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.localeService,
    this.initialErrorMessage,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<PasscodeKeypadState> _keypadKey = GlobalKey<PasscodeKeypadState>();

  void _handlePinComplete(String pin) async {
    final success = await widget.authService.login(pin);

    if (mounted) {
      if (success) {
        widget.onLoginSuccess();
      } else {
        _keypadKey.currentState?.triggerError(
          widget.localeService.t('errInvalidLogin'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeService.t;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: PasscodeKeypad(
              key: _keypadKey,
              pinLength: 6,
              title: t('loginTitle'),
              subtitle: t('loginSubtitle'),
              initialErrorMessage: widget.initialErrorMessage,
              onPinComplete: _handlePinComplete,
              headerWidget: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'IRITOT',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('appTagline'),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
