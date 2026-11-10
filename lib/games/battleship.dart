import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';
import 'grid.dart';

class Battleship extends Game {
  const Battleship();

  static const size = 8;
  static const fleet = [4, 3, 3, 2, 2];
  static final fleetCells = fleet.reduce((a, b) => a + b);

  @override
  String get id => 'battleship';
  @override
  String get name => 'Battleship';
  @override
  IconData get icon => Icons.directions_boat;
  @override
  String get help =>
      'Tap their waters to fire. A hit gives you another shot. Sink every ship to win.';

  // shortcut: fleets are placed at random, add a placement screen if wanted
  static List<int> placeFleet(Random rng) {
    final grid = List.filled(size * size, 0);
    for (final length in fleet) {
      while (true) {
        final across = rng.nextBool();
        final r = rng.nextInt(across ? size : size - length + 1);
        final c = rng.nextInt(across ? size - length + 1 : size);
        final cells = [
          for (var k = 0; k < length; k++)
            (r + (across ? 0 : k)) * size + c + (across ? k : 0),
        ];
        if (cells.every((i) => grid[i] == 0)) {
          for (final i in cells) {
            grid[i] = 1;
          }
          break;
        }
      }
    }
    return grid;
  }

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'ships': [placeFleet(rng), placeFleet(rng)],
    'shots': [List.filled(size * size, 0), List.filled(size * size, 0)],
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! int || m < 0 || m >= size * size) return null;
    final next = copyState(s);
    final shots = (next['shots'] as List)[seat] as List;
    if (shots[m] != 0) return null;
    final hit = ((next['ships'] as List)[1 - seat] as List)[m] == 1;
    shots[m] = hit ? 2 : 1;
    if (!hit) {
      next['turn'] = 1 - seat;
    } else if (shots.where((v) => v == 2).length == fleetCells) {
      next['winner'] = seat;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    void shot(Canvas canvas, Rect cell, int v) {
      if (v == 2) drawLabel(canvas, cell, '✕', scheme.error);
      if (v == 1) {
        canvas.drawCircle(
          cell.center,
          cell.width * 0.12,
          Paint()..color = scheme.outline,
        );
      }
    }

    List<dynamic> grid(String key, int seat) =>
        (b.state.value[key] as List)[seat] as List;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Their waters: tap to fire', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        GridBoard(
          rows: size,
          cols: size,
          repaint: b.state,
          onTap: b.play,
          semanticLabel: 'Their waters',
          paintCell: (canvas, cell, i) =>
              shot(canvas, cell, grid('shots', b.seat)[i] as int),
        ),
        const SizedBox(height: 16),
        Text('Your fleet', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: GridBoard(
            rows: size,
            cols: size,
            repaint: b.state,
            semanticLabel: 'Your fleet',
            paintCell: (canvas, cell, i) {
              if (grid('ships', b.seat)[i] == 1) {
                canvas.drawRect(
                  cell.deflate(2),
                  Paint()..color = scheme.secondaryContainer,
                );
              }
              shot(canvas, cell, grid('shots', 1 - b.seat)[i] as int);
            },
          ),
        ),
      ],
    );
  }
}
