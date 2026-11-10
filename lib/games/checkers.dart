import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

int _owner(int piece) => (piece - 1) % 2;
bool _inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

/// Each move is [from, to, captured index or -1]. Captures are mandatory.
List<List<int>> checkersMoves(List<dynamic> b, int seat, [int must = -1]) {
  final jumps = <List<int>>[], steps = <List<int>>[];
  for (var i = 0; i < 64; i++) {
    final piece = b[i] as int;
    if (piece == 0 || _owner(piece) != seat) continue;
    if (must != -1 && i != must) continue;
    final r = i ~/ 8, c = i % 8;
    for (final dr in piece > 2 ? const [-1, 1] : [seat == 0 ? -1 : 1]) {
      for (final dc in const [-1, 1]) {
        final r1 = r + dr, c1 = c + dc;
        if (!_inside(r1, c1)) continue;
        final mid = b[r1 * 8 + c1] as int;
        if (mid == 0) {
          steps.add([i, r1 * 8 + c1, -1]);
          continue;
        }
        final r2 = r1 + dr, c2 = c1 + dc;
        if (_owner(mid) != seat && _inside(r2, c2) && b[r2 * 8 + c2] == 0) {
          jumps.add([i, r2 * 8 + c2, r1 * 8 + c1]);
        }
      }
    }
  }
  if (jumps.isNotEmpty) return jumps;
  return must == -1 ? steps : const [];
}

class Checkers extends Game {
  const Checkers();

  @override
  String get id => 'checkers';
  @override
  String get name => 'Checkers';
  @override
  IconData get icon => Icons.apps;
  @override
  String get help =>
      'Tap a piece, then a dotted square. You must capture when you can.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'must': -1,
    'b': [
      for (var i = 0; i < 64; i++)
        (i ~/ 8 + i % 8).isEven
            ? 0
            : i < 24
            ? 2
            : i >= 40
            ? 1
            : 0,
    ],
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat || m is! int) return null;
    final from = m ~/ 64, to = m % 64;
    final legal = checkersMoves(s['b'] as List, seat, s['must'] as int);
    final chosen = legal.where((x) => x[0] == from && x[1] == to).firstOrNull;
    if (chosen == null) return null;

    final next = copyState(s);
    final b = next['b'] as List;
    var piece = b[from] as int;
    final crowned = piece <= 2 && to ~/ 8 == (seat == 0 ? 0 : 7);
    if (crowned) piece += 2;
    b[from] = 0;
    b[to] = piece;
    next['must'] = -1;
    if (chosen[2] != -1) {
      b[chosen[2]] = 0;
      final more = checkersMoves(b, seat, to);
      if (!crowned && more.isNotEmpty && more.first[2] != -1) {
        next['must'] = to;
        return next;
      }
    }
    if (checkersMoves(b, 1 - seat).isEmpty) {
      next['winner'] = seat;
    } else {
      next['turn'] = 1 - seat;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) => _CheckersBoard(b);
}

class _CheckersBoard extends StatefulWidget {
  const _CheckersBoard(this.board);

  final Board board;

  @override
  State<_CheckersBoard> createState() => _CheckersBoardState();
}

class _CheckersBoardState extends State<_CheckersBoard> {
  final _selected = ValueNotifier(-1);

  Board get _b => widget.board;

  // Seat 1 sees the board rotated so its own pieces are at the bottom.
  int _cell(int shown) => _b.seat == 0 ? shown : 63 - shown;

  List<List<int>> _legal() {
    final s = _b.state.value;
    if (winnerOf(s) != null || turnOf(s) != _b.seat) return const [];
    return checkersMoves(s['b'] as List, _b.seat, s['must'] as int);
  }

  void _tap(int shown) {
    final i = _cell(shown);
    final legal = _legal();
    if (legal.any((m) => m[0] == _selected.value && m[1] == i)) {
      _b.play(_selected.value * 64 + i);
      _selected.value = -1;
    } else {
      _selected.value = legal.any((m) => m[0] == i) ? i : -1;
    }
  }

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridBoard(
      rows: 8,
      cols: 8,
      repaint: Listenable.merge([_b.state, _selected]),
      onTap: _tap,
      paintCell: (canvas, cell, shown) {
        final i = _cell(shown);
        if ((i ~/ 8 + i % 8).isEven) return;
        final selected = _selected.value;
        canvas.drawRect(
          cell,
          Paint()
            ..color = i == selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
        );
        final piece = (_b.state.value['b'] as List)[i] as int;
        if (piece != 0) {
          drawDisc(canvas, cell, seatColor(scheme, _owner(piece)));
          if (piece > 2) drawLabel(canvas, cell, '♛', scheme.surface);
        } else if (_legal().any((m) => m[0] == selected && m[1] == i)) {
          canvas.drawCircle(
            cell.center,
            cell.width * 0.12,
            Paint()..color = scheme.outline,
          );
        }
      },
    );
  }
}
