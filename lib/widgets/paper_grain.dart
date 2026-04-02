import 'dart:math';
import 'package:flutter/material.dart';

/// Subtle paper grain texture overlay — gives the reader a mushaf feel.
class PaperGrainOverlay extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const PaperGrainOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PaperGrainPainter(isDark: isDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  final bool isDark;

  _PaperGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // fixed seed = deterministic grain
    final int dotCount = (size.width * size.height / 35).toInt().clamp(0, 25000);

    // Warm parchment tint underneath
    final tintPaint = Paint()
      ..color = isDark
          ? const Color(0x08D4AF37) // very faint gold tint in dark mode
          : const Color(0x0CA68A4B); // slightly warmer in light mode

    canvas.drawRect(Offset.zero & size, tintPaint);

    // Grain dots
    for (int i = 0; i < dotCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 0.8 + 0.2; // 0.2 - 1.0 px

      final opacity = isDark
          ? rng.nextDouble() * 0.07 + 0.02  // 2-9% white specks
          : rng.nextDouble() * 0.06 + 0.02; // 2-8% dark specks

      final color = isDark
          ? Color.fromRGBO(210, 190, 150, opacity)  // warm light specks
          : Color.fromRGBO(120, 90, 50, opacity);    // warm dark specks

      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Subtle vignette at edges for a worn-page look
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: isDark
            ? [Colors.transparent, const Color(0x15000000)]
            : [Colors.transparent, const Color(0x0A6B4F2A)],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_PaperGrainPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
