import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:duet/games/checkers.dart';
import 'package:duet/games/dots_and_boxes.dart';
import 'package:duet/games/game.dart';
import 'package:duet/games/line_games.dart';
import 'package:duet/games/reversi.dart';

import 'play.dart';

void main() {
  final rng = Random(1);

  group('four in a row', () {
    const game = FourInARow();

    test('discs stack and a full column is rejected', () {
      var s = playAll(game, game.start(0, rng), [3, 3, 3, 3, 3, 3]);
      final b = s['b'] as List;
      expect([for (var r = 0; r < 6; r++) b[r * 7 + 3]], [2, 1, 2, 1, 2, 1]);
      expect(game.move(s, 0, 3), isNull);
      expect(game.move(s, 1, 0), isNull);
      expect(game.move(s, 0, 7), isNull);
    });

    test('vertical, horizontal and diagonal wins', () {
      expect(
        winnerOf(playAll(game, game.start(0, rng), [0, 1, 0, 1, 0, 1, 0])),
        0,
      );
      expect(
        winnerOf(playAll(game, game.start(1, rng), [0, 0, 1, 1, 2, 2, 3])),
        1,
      );
      final diagonal = playAll(game, game.start(0, rng), [
        0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3, //
      ]);
      expect(winnerOf(diagonal), 0);
      expect(game.move(diagonal, 1, 5), isNull);
    });
  });

  group('gomoku', () {
    const game = Gomoku();

    test('five in a row wins, four does not, occupied is rejected', () {
      var s = playAll(game, game.start(0, rng), [0, 13, 1, 14, 2, 15, 3, 16]);
      expect(winnerOf(s), isNull);
      expect(game.move(s, 0, 13), isNull);
      s = game.move(s, 0, 4)!;
      expect(winnerOf(s), 0);
    });

    test('a line does not wrap around the board edge', () {
      final s = playAll(game, game.start(0, rng), [
        11, 50, 12, 51, 13, 52, 14, 53, 15, //
      ]);
      expect(winnerOf(s), isNull);
    });
  });

  group('reversi', () {
    const game = Reversi();

    test('a move must flip something and flips the bracketed discs', () {
      final start = game.start(0, rng);
      expect(game.move(start, 0, 0), isNull);
      expect(game.move(start, 1, 19), isNull);
      final s = game.move(start, 0, 26)!;
      final b = s['b'] as List;
      expect([b[26], b[27], b[28]], [1, 1, 1]);
      expect(turnOf(s), 1);
    });

    test('the player with no move is skipped and the game ends by count', () {
      final b = List.filled(64, 0)
        ..[0] = 1
        ..[1] = 2;
      final s = game.move({'turn': 0, 'b': b}, 0, 2)!;
      expect(winnerOf(s), 0);

      final c = List.filled(64, 0)
        ..[0] = 1
        ..[1] = 2
        ..[9] = 2
        ..[63] = 2;
      final skipped = game.move({'turn': 0, 'b': c}, 0, 2)!;
      expect(winnerOf(skipped), isNull);
      expect(turnOf(skipped), 0);
    });
  });

  group('dots and boxes', () {
    const game = DotsAndBoxes();
    const h = DotsAndBoxes.hCount;

    test('closing a box scores it and gives another turn', () {
      var s = playAll(game, game.start(0, rng), [0, 4, h]);
      expect(turnOf(s), 1);
      expect(game.move(s, 1, 0), isNull);
      s = game.move(s, 1, h + 1)!;
      expect((s['o'] as List)[0], 2);
      expect(turnOf(s), 1);
      expect(game.move(s, 0, 1), isNull);
    });

    test('the game ends when every box is owned', () {
      var s = game.start(0, rng);
      for (var m = 0; m < h * 2; m++) {
        s = game.move(s, turnOf(s), m)!;
      }
      expect((s['o'] as List).contains(0), isFalse);
      expect(winnerOf(s), isNotNull);
      expect(game.move(s, 0, 0), isNull);
    });

    test('a tap picks the nearest edge', () {
      expect(DotsAndBoxes.edgeAt(const Offset(18, 8), 100), 0);
      expect(DotsAndBoxes.edgeAt(const Offset(8, 18), 100), h);
      expect(DotsAndBoxes.edgeAt(const Offset(92, 80), 100), h + 3 * 5 + 4);
    });
  });

  group('checkers', () {
    const game = Checkers();

    GameState position(Map<int, int> pieces, {int turn = 0}) => {
      'turn': turn,
      'must': -1,
      'b': List.filled(64, 0)
        ..setAll(0, [for (var i = 0; i < 64; i++) pieces[i] ?? 0]),
    };

    test('opening has seven moves and men only go forward', () {
      final s = game.start(0, rng);
      expect(checkersMoves(s['b'] as List, 0), hasLength(7));
      expect(game.move(s, 0, 40 * 64 + 33), isNotNull);
      expect(game.move(s, 0, 40 * 64 + 49), isNull);
      expect(game.move(s, 1, 17 * 64 + 24), isNull);
    });

    test('a capture is mandatory and removes the piece', () {
      final s = position({35: 1, 26: 2, 44: 1, 1: 2});
      expect(game.move(s, 0, 44 * 64 + 37), isNull);
      final next = game.move(s, 0, 35 * 64 + 17)!;
      expect((next['b'] as List)[26], 0);
      expect(turnOf(next), 1);
    });

    test('a double jump keeps the turn and must use the same piece', () {
      final s = position({44: 1, 35: 2, 17: 2, 62: 1, 1: 2});
      final mid = game.move(s, 0, 44 * 64 + 26)!;
      expect(turnOf(mid), 0);
      expect(mid['must'], 26);
      expect(game.move(mid, 0, 62 * 64 + 53), isNull);
      final done = game.move(mid, 0, 26 * 64 + 8)!;
      expect(turnOf(done), 1);
    });

    test('reaching the far row crowns, and kings move backwards', () {
      final s = position({10: 1, 21: 2});
      final crowned = game.move(s, 0, 10 * 64 + 1)!;
      expect((crowned['b'] as List)[1], 3);
      final back = playAll(game, crowned, [21 * 64 + 28]);
      expect(game.move(back, 0, 1 * 64 + 10), isNotNull);
    });

    test('taking the last piece wins', () {
      final s = position({35: 1, 26: 2});
      expect(winnerOf(game.move(s, 0, 35 * 64 + 17)!), 0);
    });
  });
}
