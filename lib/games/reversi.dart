import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

List<int> reversiFlips(List<dynamic> b, int i, int v) {
  if (b[i] != 0) return const [];
  final out = <int>[];
  for (var dr = -1; dr <= 1; dr++) {
    for (var dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      final line = <int>[];
      var r = i ~/ 8 + dr, c = i % 8 + dc;
      bool inside() => r >= 0 && r < 8 && c >= 0 && c < 8;
      while (inside() && b[r * 8 + c] != 0 && b[r * 8 + c] != v) {
        line.add(r * 8 + c);
        r += dr;
        c += dc;
      }
      if (line.isNotEmpty && inside() && b[r * 8 + c] == v) out.addAll(line);
    }
  }
  return out;
}

bool _canMove(List<dynamic> b, int v) {
  for (var i = 0; i < 64; i++) {
    if (reversiFlips(b, i, v).isNotEmpty) return true;
  }
  return false;
}

class Reversi extends Game {
  const Reversi();

  @override
  String get id => 'reversi';
  @override
  String get name => 'Reversi';
  @override
  IconData get icon => Icons.contrast;
  @override
  String get help =>
      'Tap a dotted square to trap and flip their discs. Most discs wins.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'b': List.filled(64, 0)
      ..[27] = 2
      ..[36] = 2
      ..[28] = 1
      ..[35] = 1,
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m > 63) return null;
    final flips = reversiFlips(s['b'] as List, m, seat + 1);
    if (flips.isEmpty) return null;
    final next = copyState(s);
    final b = next['b'] as List;
    for (final i in [m, ...flips]) {
      b[i] = seat + 1;
    }
    if (_canMove(b, 2 - seat)) {
      next['turn'] = 1 - seat;
    } else if (!_canMove(b, seat + 1)) {
      final mine = b.where((v) => v == seat + 1).length;
      final theirs = b.where((v) => v == 2 - seat).length;
      next['winner'] = mine == theirs
          ? drawn
          : mine > theirs
          ? seat
          : 1 - seat;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final scheme = Theme.of(context).colorScheme;
    return GridBoard(
      rows: 8,
      cols: 8,
      repaint: b.state,
      onTap: b.play,
      paintCell: (canvas, cell, i) {
        final s = b.state.value;
        final cells = s['b'] as List;
        final v = cells[i] as int;
        if (v != 0) {
          drawDisc(canvas, cell, seatColor(scheme, v - 1));
        } else if (winnerOf(s) == null &&
            turnOf(s) == b.seat &&
            reversiFlips(cells, i, b.seat + 1).isNotEmpty) {
          canvas.drawCircle(
            cell.center,
            cell.width * 0.1,
            Paint()..color = scheme.outline,
          );
        }
      },
    );
  }
}
