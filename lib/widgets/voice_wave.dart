import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated equalizer bars shown while the microphone is listening.
class VoiceWave extends StatefulWidget {
  final Color color;
  final double height;
  final int bars;

  const VoiceWave({
    super.key,
    required this.color,
    this.height = 28,
    this.bars = 5,
  });

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.bars, (i) {
              final phase = (_controller.value * 2 * math.pi) + i * 0.9;
              final level = 0.3 + 0.7 * ((math.sin(phase) + 1) / 2);
              return Container(
                width: 4,
                height: widget.height * level,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Pulsing glow used behind a microphone icon while recording.
class PulsingMic extends StatefulWidget {
  final bool active;
  final Color color;
  final Widget child;

  const PulsingMic({
    super.key,
    required this.active,
    required this.color,
    required this.child,
  });

  @override
  State<PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<PulsingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PulsingMic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                      blurRadius: 4 + 14 * t,
                      spreadRadius: 1 + 6 * t,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
