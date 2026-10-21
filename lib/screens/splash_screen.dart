import 'dart:async';
import 'package:flutter/material.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final LocaleService localeService;
  final VoidCallback onFinish;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.localeService,
    required this.onFinish,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    _timer = Timer(widget.duration, () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orbitController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF080D1A),
              Color(0xFF04070D),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle ambient glow in center
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.08),
                          blurRadius: 90,
                          spreadRadius: 20,
                        ),
                        BoxShadow(
                          color: AppTheme.cyanAccent.withValues(alpha: 0.08),
                          blurRadius: 110,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center content with entrance animation
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Growth Orbit Ring & Floating Upward Icon
                        SizedBox(
                          width: 104,
                          height: 104,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rotating Orbit Ring
                              RotationTransition(
                                turns: _orbitController,
                                child: CustomPaint(
                                  size: const Size(100, 100),
                                  painter: OrbitRingPainter(),
                                ),
                              ),
                              // Floating Inner Growth Card
                              AnimatedBuilder(
                                animation: _floatController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(0, -4 * _floatController.value),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.emeraldGreen.withValues(alpha: 0.20),
                                        AppTheme.cyanAccent.withValues(alpha: 0.20),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.cyanAccent.withValues(alpha: 0.55),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.emeraldGreen.withValues(alpha: 0.30),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.trending_up_rounded,
                                      color: AppTheme.cyanAccent,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),

                        // IRITOT Brand Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Colors.white,
                              AppTheme.emeraldGreen,
                              AppTheme.cyanAccent,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'IRITOT',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // SMART WEALTH FLOW Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.emeraldGreen.withValues(alpha: 0.32),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.localeService.t('splashBadge'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.emeraldGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          widget.localeService.t('splashSubtitle'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom status line
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emeraldGreen.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.localeService.t('splashDecryption'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;

    // Track circle
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, bgPaint);

    // Glowing dynamic arc
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF10B981),
          Color(0xFF38BDF8),
          Colors.transparent,
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      4.2, // ~240 degrees sweep
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
