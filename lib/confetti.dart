import 'dart:math';

import 'package:flutter/material.dart';

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.burst, this.colors) : super(repaint: burst);

  final Animation<double> burst;
  final List<Color> colors;

  static final _pieces = () {
    final rng = Random(3);
    return [
      for (var i = 0; i < 90; i++)
        (
          angle: -pi * rng.nextDouble(),
          speed: 0.5 + rng.nextDouble() * 1.1,
          spin: (rng.nextDouble() - 0.5) * 16,
          width: 6 + rng.nextDouble() * 6,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = burst.value;
    if (t == 0 || t == 1) return;
    final seconds = t * 2.4;
    final fade = ((1 - t) / 0.3).clamp(0.0, 1.0);
    final paint = Paint();
    for (final (i, p) in _pieces.indexed) {
      final dx = cos(p.angle) * p.speed * seconds * size.width * 0.6;
      final dy =
          (sin(p.angle) * p.speed * seconds + 0.45 * seconds * seconds) *
          size.height *
          0.5;
      canvas
        ..save()
        ..translate(size.width / 2 + dx, size.height * 0.4 + dy)
        ..rotate(p.spin * seconds);
      paint.color = colors[i % colors.length].withValues(alpha: fade);
      canvas
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.width * 1.6,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.colors != colors;
}
