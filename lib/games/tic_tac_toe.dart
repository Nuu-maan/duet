import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

class TicTacToe extends Game {
  const TicTacToe();

  @override
  String get id => 'tictactoe';
  @override
  String get name => 'Tic-tac-toe';
  @override
  IconData get icon => Icons.grid_3x3;
  @override
  String get help => 'Tap an empty square. Three in a row wins.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'b': List.filled(9, 0),
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m > 8) return null;
    final next = copyState(s);
    final b = next['b'] as List;
    if (b[m] != 0) return null;
    b[m] = seat + 1;
    if (lineThrough(b, 3, 3, m, 3)) {
      next['winner'] = seat;
    } else if (!b.contains(0)) {
      next['winner'] = drawn;
    } else {
      next['turn'] = 1 - seat;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final scheme = Theme.of(context).colorScheme;
    return GridBoard(
      rows: 3,
      cols: 3,
      repaint: b.state,
      onTap: b.play,
      paintCell: (canvas, cell, i) {
        final v = (b.state.value['b'] as List)[i] as int;
        if (v == 0) return;
        final stroke = Paint()
          ..color = seatColor(scheme, v - 1)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = cell.width * 0.13;
        final box = cell.deflate(cell.width * 0.27);
        if (v == 1) {
          canvas
            ..drawLine(box.topLeft, box.bottomRight, stroke)
            ..drawLine(box.topRight, box.bottomLeft, stroke);
        } else {
          canvas.drawCircle(cell.center, box.width / 2, stroke);
        }
      },
    );
  }
}
