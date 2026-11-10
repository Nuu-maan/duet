import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

class DotsAndBoxes extends Game {
  const DotsAndBoxes();

  static const n = 4;
  static const hCount = (n + 1) * n;

  @override
  String get id => 'dots';
  @override
  String get name => 'Dots and boxes';
  @override
  IconData get icon => Icons.blur_on;
  @override
  String get help =>
      'Tap between two dots to draw a line. Close a box to score and go again.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'h': List.filled(hCount, 0),
    'v': List.filled(hCount, 0),
    'o': List.filled(n * n, 0),
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m >= hCount * 2) return null;
    final next = copyState(s);
    final h = next['h'] as List, v = next['v'] as List, o = next['o'] as List;
    final edges = m < hCount ? h : v;
    final i = m % hCount;
    if (edges[i] != 0) return null;
    edges[i] = 1;
    var claimed = false;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (o[r * n + c] == 0 &&
            h[r * n + c] == 1 &&
            h[(r + 1) * n + c] == 1 &&
            v[r * (n + 1) + c] == 1 &&
            v[r * (n + 1) + c + 1] == 1) {
          o[r * n + c] = seat + 1;
          claimed = true;
        }
      }
    }
    if (!o.contains(0)) {
      final mine = o.where((x) => x == seat + 1).length;
      next['winner'] = mine * 2 == n * n
          ? drawn
          : mine * 2 > n * n
          ? seat
          : 1 - seat;
    } else if (!claimed) {
      next['turn'] = 1 - seat;
    }
    return next;
  }

  static const _margin = 0.08;

  static int? edgeAt(Offset p, double size) {
    final gap = size * (1 - 2 * _margin) / n;
    final u = (p.dx - size * _margin) / gap, v = (p.dy - size * _margin) / gap;
    final hr = v.round(), hc = u.floor();
    final vr = v.floor(), vc = u.round();
    final hOk = hr >= 0 && hr <= n && hc >= 0 && hc < n;
    final vOk = vc >= 0 && vc <= n && vr >= 0 && vr < n;
    if (hOk && (!vOk || (v - hr).abs() <= (u - vc).abs())) return hr * n + hc;
    if (vOk) return hCount + vr * (n + 1) + vc;
    return null;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Dots and boxes board',
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(
          child: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final edge = edgeAt(d.localPosition, context.size!.width);
                if (edge != null) b.play(edge);
              },
              child: CustomPaint(painter: _DotsPainter(b.state, scheme)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.state, this.scheme) : super(repaint: state);

  final ValueListenable<GameState> state;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const n = DotsAndBoxes.n;
    final s = state.value;
    final h = s['h'] as List, v = s['v'] as List, o = s['o'] as List;
    final m = size.width * DotsAndBoxes._margin;
    final gap = (size.width - 2 * m) / n;
    Offset dot(int r, int c) => Offset(m + c * gap, m + r * gap);

    for (var i = 0; i < n * n; i++) {
      if (o[i] == 0) continue;
      canvas.drawRect(
        Rect.fromPoints(dot(i ~/ n, i % n), dot(i ~/ n + 1, i % n + 1)),
        Paint()
          ..color = seatColor(scheme, (o[i] as int) - 1).withValues(alpha: 0.3),
      );
    }
    final empty = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    final drawn = Paint()
      ..color = scheme.onSurface
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < DotsAndBoxes.hCount; i++) {
      final hr = i ~/ n, hc = i % n;
      canvas.drawLine(dot(hr, hc), dot(hr, hc + 1), h[i] == 1 ? drawn : empty);
      final vr = i ~/ (n + 1), vc = i % (n + 1);
      canvas.drawLine(dot(vr, vc), dot(vr + 1, vc), v[i] == 1 ? drawn : empty);
    }
    final dots = Paint()..color = scheme.onSurface;
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        canvas.drawCircle(dot(r, c), 5, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.state != state || old.scheme != scheme;
}
