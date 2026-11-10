import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Small pictures drawn in code, so the app ships no image files.
///
/// Names: `mascot_hi`, `mascot_excited`, `mascot_shocked`, `trophy_won`,
/// `trophy_lost`, `trophy_draw`, `fire`.
class Art extends StatelessWidget {
  const Art(this.name, {super.key, this.size = 120});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playful = theme.extension<Playful>()!;
    final icon = switch (name) {
      'fire' => (Icons.local_fire_department_rounded, scheme.tertiary),
      'trophy_won' => (Icons.emoji_events_rounded, scheme.tertiary),
      'trophy_lost' => (
        Icons.sentiment_dissatisfied_rounded,
        scheme.onSurfaceVariant,
      ),
      'trophy_draw' => (Icons.handshake_rounded, scheme.primary),
      _ => null,
    };
    if (icon != null) {
      return ExcludeSemantics(
        child: Icon(icon.$1, size: size, color: icon.$2),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DuoPainter(
            mood: name,
            front: playful.paper,
            back: scheme.tertiary,
            ink: playful.onCard,
          ),
        ),
      ),
    );
  }
}

/// The mascot: two round friends leaning on each other.
class _DuoPainter extends CustomPainter {
  _DuoPainter({
    required this.mood,
    required this.front,
    required this.back,
    required this.ink,
  });

  final String mood;
  final Color front;
  final Color back;
  final Color ink;

  void _friend(Canvas canvas, Offset c, double r, Color fill, double s) {
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.035;
    final dark = Paint()..color = ink;
    canvas
      ..drawCircle(c, r, Paint()..color = fill)
      ..drawCircle(c, r, outline);

    for (final side in const [-1, 1]) {
      final eye = c + Offset(side * r * 0.36, -r * 0.12);
      if (mood == 'mascot_excited') {
        canvas.drawArc(
          Rect.fromCircle(center: eye, radius: r * 0.18),
          pi,
          pi,
          false,
          outline,
        );
      } else {
        final shocked = mood == 'mascot_shocked';
        final white = r * (shocked ? 0.26 : 0.22);
        canvas
          ..drawCircle(eye, white, Paint()..color = front)
          ..drawCircle(eye, white, outline)
          ..drawCircle(eye, r * (shocked ? 0.08 : 0.12), dark);
      }
    }

    final mouth = c + Offset(0, r * 0.34);
    if (mood == 'mascot_shocked') {
      canvas.drawOval(
        Rect.fromCenter(center: mouth, width: r * 0.26, height: r * 0.36),
        dark,
      );
    } else {
      final wide = mood == 'mascot_excited' ? 0.42 : 0.3;
      canvas.drawArc(
        Rect.fromCircle(center: mouth - Offset(0, r * 0.1), radius: r * wide),
        0,
        pi,
        true,
        dark,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    _friend(canvas, Offset(s * 0.66, s * 0.47), s * 0.27, back, s);
    _friend(canvas, Offset(s * 0.36, s * 0.57), s * 0.31, front, s);
  }

  @override
  bool shouldRepaint(_DuoPainter old) =>
      old.mood != mood ||
      old.front != front ||
      old.back != back ||
      old.ink != ink;
}

class MascotMessage extends StatelessWidget {
  const MascotMessage({
    super.key,
    required this.title,
    this.body,
    this.mascot = 'mascot_hi',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final String mascot;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Art(mascot),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
