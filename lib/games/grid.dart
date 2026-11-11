import 'dart:math';

import 'package:flutter/material.dart';

typedef CellPaint = void Function(Canvas canvas, Rect cell, int index);

Color seatColor(ColorScheme scheme, int seat) =>
    seat == 0 ? scheme.primary : scheme.tertiary;

Color _shade(Color color, double factor) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness * factor).clamp(0, 1)).toColor();
}

/// A game piece with a darker rim below and a soft highlight above, so it
/// reads as a solid token without any image.
void drawDisc(Canvas canvas, Rect cell, Color color, {double size = 0.38}) {
  final r = cell.shortestSide * size;
  final c = cell.center;
  canvas
    ..drawCircle(
      c + Offset(0, r * 0.14),
      r,
      Paint()..color = _shade(color, 0.6),
    )
    ..drawCircle(c - Offset(0, r * 0.04), r, Paint()..color = color)
    ..drawCircle(
      c - Offset(r * 0.32, r * 0.38),
      r * 0.2,
      Paint()..color = _shade(color, 1.35).withValues(alpha: 0.7),
    );
}

void drawLabel(Canvas canvas, Rect cell, String text, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: cell.height * 0.6,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    cell.center - Offset(painter.width / 2, painter.height / 2),
  );
  painter.dispose();
}

void drawIcon(Canvas canvas, Rect cell, IconData icon, Color color) {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: color,
        fontSize: cell.shortestSide * 0.56,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    cell.center - Offset(painter.width / 2, painter.height / 2),
  );
  painter.dispose();
}

void drawStar(Canvas canvas, Offset centre, double radius, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final p = centre + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), Paint()..color = color);
}

enum Tiles { square, round, none }

/// A rounded panel with one tile per cell. Games paint their pieces on top.
class GridBoard extends StatelessWidget {
  const GridBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.repaint,
    required this.paintCell,
    this.onTap,
    this.tiles = Tiles.square,
    this.panel,
    this.semanticLabel = 'Game board',
  });

  static const _margin = 6.0;

  final int rows;
  final int cols;
  final Listenable repaint;
  final CellPaint paintCell;
  final void Function(int index)? onTap;
  final Tiles tiles;
  final Color? panel;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: AspectRatio(
        aspectRatio: cols / rows,
        child: RepaintBoundary(
          child: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onTap == null
                  ? null
                  : (details) {
                      final size = context.size!;
                      final p = details.localPosition;
                      final c =
                          ((p.dx - _margin) * cols / (size.width - 2 * _margin))
                              .floor();
                      final r =
                          ((p.dy - _margin) *
                                  rows /
                                  (size.height - 2 * _margin))
                              .floor();
                      if (r >= 0 && r < rows && c >= 0 && c < cols) {
                        onTap!(r * cols + c);
                      }
                    },
              child: CustomPaint(
                painter: _GridPainter(
                  rows: rows,
                  cols: cols,
                  tiles: tiles,
                  panel: panel ?? scheme.surfaceContainerHighest,
                  tile: scheme.surface,
                  paintCell: paintCell,
                  repaint: repaint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.cols,
    required this.tiles,
    required this.panel,
    required this.tile,
    required this.paintCell,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final int rows;
  final int cols;
  final Tiles tiles;
  final Color panel;
  final Color tile;
  final CellPaint paintCell;

  @override
  void paint(Canvas canvas, Size size) {
    const m = GridBoard._margin;
    final w = (size.width - 2 * m) / cols, h = (size.height - 2 * m) / rows;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      Paint()..color = panel,
    );
    final tilePaint = Paint()..color = tile;
    final gap = max(1.0, w * 0.05);
    for (var i = 0; i < rows * cols; i++) {
      final cell = Rect.fromLTWH(m + (i % cols) * w, m + (i ~/ cols) * h, w, h);
      switch (tiles) {
        case Tiles.square:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              cell.deflate(gap),
              Radius.circular(w * 0.18),
            ),
            tilePaint,
          );
        case Tiles.round:
          canvas.drawCircle(cell.center, w * 0.42, tilePaint);
        case Tiles.none:
      }
      paintCell(canvas, cell, i);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.tiles != tiles ||
      old.panel != panel ||
      old.tile != tile ||
      old.paintCell != paintCell;
}
