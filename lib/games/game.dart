import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef GameState = Map<String, dynamic>;

const bothSeats = -1;
const drawn = 2;

int turnOf(GameState s) => s['turn'] as int;
int? winnerOf(GameState s) => s['winner'] as int?;
GameState copyState(GameState s) => jsonDecode(jsonEncode(s)) as GameState;

class Board {
  const Board({
    required this.state,
    required this.seat,
    required this.play,
    this.friend = 'Friend',
  });

  final ValueListenable<GameState> state;
  final int seat;
  final String friend;
  final void Function(Object? move) play;
}

abstract class Game {
  const Game();

  String get id;
  String get name;
  IconData get icon;
  String get help;

  GameState start(int first, Random rng);

  bool waitsFor(GameState s, int seat) =>
      turnOf(s) == seat || turnOf(s) == bothSeats;

  /// Returns the next state, or null when the move is not legal.
  /// Must not mutate [s]: the caller keeps using it when the move is rejected.
  GameState? move(GameState s, int seat, Object? m);

  Widget board(BuildContext context, Board b);
}

bool lineThrough(List<dynamic> b, int rows, int cols, int i, int n) {
  final v = b[i];
  if (v == 0) return false;
  final r = i ~/ cols, c = i % cols;
  int run(int dr, int dc) {
    var count = 0;
    var rr = r + dr, cc = c + dc;
    while (rr >= 0 &&
        rr < rows &&
        cc >= 0 &&
        cc < cols &&
        b[rr * cols + cc] == v) {
      count++;
      rr += dr;
      cc += dc;
    }
    return count;
  }

  for (final d in const [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1],
  ]) {
    if (1 + run(d[0], d[1]) + run(-d[0], -d[1]) >= n) return true;
  }
  return false;
}
