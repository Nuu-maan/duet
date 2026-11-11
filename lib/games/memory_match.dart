import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

class MemoryMatch extends Game {
  const MemoryMatch();

  static const faces = [
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.pets_rounded,
    Icons.music_note_rounded,
    Icons.rocket_launch_rounded,
    Icons.cake_rounded,
    Icons.wb_sunny_rounded,
    Icons.local_florist_rounded,
  ];

  @override
  String get id => 'memory';
  @override
  String get name => 'Memory match';
  @override
  IconData get icon => Icons.style;
  @override
  String get help =>
      'Flip two cards. A matching pair is yours and you go again.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'cards': [for (var i = 0; i < 16; i++) i ~/ 2]..shuffle(rng),
    'found': List.filled(16, 0),
    'up': <int>[],
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m > 15) return null;
    final next = copyState(s);
    final cards = next['cards'] as List, found = next['found'] as List;
    var up = next['up'] as List;
    // A mismatched pair stays face up until the next player flips.
    if (up.length == 2) up = next['up'] = <dynamic>[];
    if (found[m] != 0 || up.contains(m)) return null;
    up.add(m);
    if (up.length < 2) return next;
    if (cards[up[0] as int] != cards[up[1] as int]) {
      next['turn'] = 1 - seat;
      return next;
    }
    found[up[0] as int] = found[up[1] as int] = seat + 1;
    next['up'] = <dynamic>[];
    if (!found.contains(0)) {
      final mine = found.where((v) => v == seat + 1).length;
      next['winner'] = mine == 8
          ? drawn
          : mine > 8
          ? seat
          : 1 - seat;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final scheme = Theme.of(context).colorScheme;
    return GridBoard(
      rows: 4,
      cols: 4,
      repaint: b.state,
      onTap: b.play,
      tiles: Tiles.none,
      paintCell: (canvas, cell, i) {
        final s = b.state.value;
        final owner = (s['found'] as List)[i] as int;
        final shown = owner != 0 || (s['up'] as List).contains(i);
        final card = RRect.fromRectAndRadius(
          cell.deflate(cell.width * 0.06),
          Radius.circular(cell.width * 0.16),
        );
        if (!shown) {
          canvas
            ..drawRRect(card, Paint()..color = scheme.primaryContainer)
            ..drawRRect(
              card.deflate(cell.width * 0.09),
              Paint()
                ..color = scheme.onPrimaryContainer.withValues(alpha: 0.35)
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell.width * 0.035,
            );
          drawStar(
            canvas,
            cell.center,
            cell.width * 0.13,
            scheme.onPrimaryContainer.withValues(alpha: 0.45),
          );
          return;
        }
        canvas.drawRRect(card, Paint()..color = scheme.surface);
        if (owner != 0) {
          canvas.drawRRect(
            card,
            Paint()
              ..color = seatColor(scheme, owner - 1)
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell.width * 0.06,
          );
        }
        drawIcon(
          canvas,
          cell,
          faces[(s['cards'] as List)[i] as int],
          owner != 0 ? seatColor(scheme, owner - 1) : scheme.onSurface,
        );
      },
    );
  }
}
