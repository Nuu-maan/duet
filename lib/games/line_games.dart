import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

Widget _discBoard(
  BuildContext context,
  Board b,
  int rows,
  int cols,
  void Function(int index) onTap, {
  Tiles tiles = Tiles.square,
}) {
  final scheme = Theme.of(context).colorScheme;
  return GridBoard(
    rows: rows,
    cols: cols,
    repaint: b.state,
    onTap: onTap,
    tiles: tiles,
    panel: tiles == Tiles.round ? scheme.primaryContainer : null,
    paintCell: (canvas, cell, i) {
      final v = (b.state.value['b'] as List)[i] as int;
      if (v != 0) drawDisc(canvas, cell, seatColor(scheme, v - 1));
    },
  );
}

GameState? _place(GameState s, int seat, int i, int rows, int cols, int n) {
  final next = copyState(s);
  final b = next['b'] as List;
  b[i] = seat + 1;
  if (lineThrough(b, rows, cols, i, n)) {
    next['winner'] = seat;
  } else if (!b.contains(0)) {
    next['winner'] = drawn;
  } else {
    next['turn'] = 1 - seat;
  }
  return next;
}

class FourInARow extends Game {
  const FourInARow();

  static const rows = 6, cols = 7;

  @override
  String get id => 'four';
  @override
  String get name => 'Four in a row';
  @override
  IconData get icon => Icons.view_column;
  @override
  String get help => 'Tap a column to drop a disc. Four in a row wins.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'b': List.filled(rows * cols, 0),
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m >= cols) return null;
    final b = s['b'] as List;
    for (var r = rows - 1; r >= 0; r--) {
      if (b[r * cols + m] == 0) {
        return _place(s, seat, r * cols + m, rows, cols, 4);
      }
    }
    return null;
  }

  @override
  Widget board(BuildContext context, Board b) => _discBoard(
    context,
    b,
    rows,
    cols,
    (i) => b.play(i % cols),
    tiles: Tiles.round,
  );
}

class Gomoku extends Game {
  const Gomoku();

  static const size = 13;

  @override
  String get id => 'gomoku';
  @override
  String get name => 'Gomoku';
  @override
  IconData get icon => Icons.grid_on;
  @override
  String get help => 'Tap to place a stone. Five in a row wins.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'b': List.filled(size * size, 0),
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m >= size * size) return null;
    if ((s['b'] as List)[m] != 0) return null;
    return _place(s, seat, m, size, size, 5);
  }

  @override
  Widget board(BuildContext context, Board b) =>
      _discBoard(context, b, size, size, b.play);
}
