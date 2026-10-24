import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasscodeKeypad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? initialErrorMessage;
  final int pinLength;
  final ValueChanged<String> onPinComplete;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final Widget? headerWidget;

  const PasscodeKeypad({
    super.key,
    required this.title,
    this.subtitle,
    this.initialErrorMessage,
    this.pinLength = 6,
    required this.onPinComplete,
    this.onCancel,
    this.cancelLabel,
    this.headerWidget,
  });

  @override
  State<PasscodeKeypad> createState() => PasscodeKeypadState();
}

class PasscodeKeypadState extends State<PasscodeKeypad> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final TextEditingController _hiddenInputController = TextEditingController();
  final FocusNode _hiddenFocusNode = FocusNode();

  String _currentPin = '';
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant PasscodeKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialErrorMessage != oldWidget.initialErrorMessage &&
        widget.initialErrorMessage != null) {
      triggerError(widget.initialErrorMessage!);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hiddenInputController.dispose();
    _hiddenFocusNode.dispose();
    super.dispose();
  }

  /// Pemicu animasi getar iOS saat PIN salah
  void triggerError(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
    });

    _shakeController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentPin = '';
          _hiddenInputController.clear();
        });
      }
    });
  }

  void _handleDigitPress(String digit) {
    if (_isProcessing || _currentPin.length >= widget.pinLength) return;

    HapticFeedback.lightImpact();

    setState(() {
      _errorMessage = null;
      _currentPin += digit;
      _hiddenInputController.text = _currentPin;
    });

    if (_currentPin.length == widget.pinLength) {
      _submitPin(_currentPin);
    }
  }

  void _handleBackspace() {
    if (_isProcessing || _currentPin.isEmpty) return;

    HapticFeedback.selectionClick();

    setState(() {
      _errorMessage = null;
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      _hiddenInputController.text = _currentPin;
    });
  }

  void _handleClearAll() {
    if (_isProcessing || _currentPin.isEmpty) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _errorMessage = null;
      _currentPin = '';
      _hiddenInputController.clear();
    });
  }

  void _submitPin(String pin) {
    setState(() {
      _isProcessing = true;
    });
    widget.onPinComplete(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sembunyikan TextField 1x1 untuk kompatibilitas input fisik & testing otomatis
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _hiddenInputController,
              focusNode: _hiddenFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.pinLength),
              ],
              onChanged: (val) {
                if (_isProcessing) return;
                setState(() {
                  _errorMessage = null;
                  _currentPin = val;
                });
                if (_currentPin.length == widget.pinLength) {
                  _submitPin(_currentPin);
                }
              },
            ),
          ),
        ),

        if (widget.headerWidget != null) ...[
          widget.headerWidget!,
          const SizedBox(height: 16),
        ],

        // Judul (Enter Passcode)
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle / Error message
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF43F5E), // Coral Rose
            ),
            textAlign: TextAlign.center,
          )
        else if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          )
        else
          const SizedBox(height: 16),

        const SizedBox(height: 24),

        // 6 Dots Indikator PIN dengan Animasi Shake iOS
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final t = _shakeAnimation.value;
            final dx = sin(t * pi * 6) * 12 * (1.0 - t);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < _currentPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? Colors.white : Colors.white.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 36),

        // Keypad Grid 3x4 Gaya iOS (Sesuai Contoh_UI_PIN.jpeg)
        _buildKeypadGrid(),
      ],
    );
  }

  Widget _buildKeypadGrid() {
    return Column(
      children: [
        _buildKeypadRow([
          _KeypadData('1', ''),
          _KeypadData('2', 'ABC'),
          _KeypadData('3', 'DEF'),
        ]),
        const SizedBox(height: 16),
        _buildKeypadRow([
          _KeypadData('4', 'GHI'),
          _KeypadData('5', 'JKL'),
          _KeypadData('6', 'MNO'),
        ]),
        const SizedBox(height: 16),
        _buildKeypadRow([
          _KeypadData('7', 'PQRS'),
          _KeypadData('8', 'TUV'),
          _KeypadData('9', 'WXYZ'),
        ]),
        const SizedBox(height: 16),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildKeypadRow(List<_KeypadData> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildKeypadButton(
            number: k.digit,
            letters: k.letters,
            onTap: () => _handleDigitPress(k.digit),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Sisi Kiri Bawah (Bisa Batal jika ada callback onCancel)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: 76,
            height: 76,
            child: widget.onCancel != null && _currentPin.isEmpty
                ? Center(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        widget.cancelLabel ?? 'Cancel',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ),

        // Tombol Angka 0 di Tengah
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildKeypadButton(
            number: '0',
            letters: '',
            onTap: () => _handleDigitPress('0'),
          ),
        ),

        // Sisi Kanan Bawah (Delete / Backspace atau Cancel saat kosong)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            width: 76,
            height: 76,
            child: _currentPin.isNotEmpty
                ? Center(
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _handleBackspace,
                        onLongPress: _handleClearAll,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withValues(alpha: 0.25),
                        highlightColor: Colors.white.withValues(alpha: 0.15),
                        child: const Padding(
                          padding: EdgeInsets.all(18.0),
                          child: Icon(
                            Icons.backspace_outlined,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : (widget.onCancel != null
                    ? Center(
                        child: TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            widget.cancelLabel ?? 'Cancel',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox()),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton({
    required String number,
    required String letters,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withValues(alpha: 0.3),
          highlightColor: Colors.white.withValues(alpha: 0.2),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                if (letters.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    letters,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadData {
  final String digit;
  final String letters;
  _KeypadData(this.digit, this.letters);
}
