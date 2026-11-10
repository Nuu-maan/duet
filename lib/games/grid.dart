import 'package:flutter/material.dart';

typedef CellPaint = void Function(Canvas canvas, Rect cell, int index);

Color seatColor(ColorScheme scheme, int seat) =>
    seat == 0 ? scheme.primary : scheme.tertiary;

void drawDisc(Canvas canvas, Rect cell, Color color, {bool ring = false}) {
  final paint = Paint()..color = color;
  if (ring) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell.width * 0.1;
  }
  canvas.drawCircle(cell.center, cell.width * 0.36, paint);
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

class GridBoard extends StatelessWidget {
  const GridBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.repaint,
    required this.paintCell,
    this.onTap,
    this.semanticLabel = 'Game board',
  });

  final int rows;
  final int cols;
  final Listenable repaint;
  final CellPaint paintCell;
  final void Function(int index)? onTap;
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
                      final c = details.localPosition.dx * cols ~/ size.width;
                      final r = details.localPosition.dy * rows ~/ size.height;
                      if (r >= 0 && r < rows && c >= 0 && c < cols) {
                        onTap!(r * cols + c);
                      }
                    },
              child: CustomPaint(
                painter: _GridPainter(
                  rows: rows,
                  cols: cols,
                  line: scheme.outlineVariant,
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
    required this.line,
    required this.paintCell,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final int rows;
  final int cols;
  final Color line;
  final CellPaint paintCell;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / cols, h = size.height / rows;
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * h), Offset(size.width, r * h), paint);
    }
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * w, 0), Offset(c * w, size.height), paint);
    }
    for (var i = 0; i < rows * cols; i++) {
      paintCell(
        canvas,
        Rect.fromLTWH((i % cols) * w, (i ~/ cols) * h, w, h),
        i,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.line != line ||
      old.paintCell != paintCell;
}
