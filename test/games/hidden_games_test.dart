import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:duet/games/battleship.dart';
import 'package:duet/games/game.dart';
import 'package:duet/games/hangman.dart';
import 'package:duet/games/memory_match.dart';
import 'package:duet/games/rock_paper_scissors.dart';

void main() {
  group('rock paper scissors', () {
    const game = RockPaperScissors();

    test('a round resolves only after both pick, and picks are locked', () {
      var s = game.move(game.start(0, Random(1)), 0, 0)!;
      expect(s['score'], [0, 0]);
      expect(game.move(s, 0, 1), isNull);
      expect(game.move(s, 1, 3), isNull);
      s = game.move(s, 1, 1)!;
      expect(s['score'], [0, 1]);
      expect(s['last'], [0, 1]);
      expect(s['picks'], [-1, -1]);
    });

    test('ties score nothing and first to three wins', () {
      var s = game.start(0, Random(1));
      s = game.move(game.move(s, 1, 2)!, 0, 2)!;
      expect(s['score'], [0, 0]);
      for (var i = 0; i < 3; i++) {
        expect(winnerOf(s), isNull);
        s = game.move(game.move(s, 0, 2)!, 1, 1)!;
      }
      expect(winnerOf(s), 0);
      expect(game.move(s, 1, 0), isNull);
    });
  });

  group('battleship', () {
    const game = Battleship();

    test('fleets have every ship cell on the board', () {
      for (var seed = 0; seed < 50; seed++) {
        final grid = Battleship.placeFleet(Random(seed));
        expect(grid.where((v) => v == 1), hasLength(Battleship.fleetCells));
      }
    });

    test('a miss passes the turn, a hit keeps it, repeats are rejected', () {
      final s = game.start(0, Random(3));
      final theirs = (s['ships'] as List)[1] as List;
      final water = theirs.indexOf(0), ship = theirs.indexOf(1);

      final miss = game.move(s, 0, water)!;
      expect(turnOf(miss), 1);
      expect(game.move(miss, 0, ship), isNull);

      final hit = game.move(s, 0, ship)!;
      expect(turnOf(hit), 0);
      expect(game.move(hit, 0, ship), isNull);
    });

    test('sinking every ship cell wins', () {
      var s = game.start(1, Random(3));
      final theirs = (s['ships'] as List)[0] as List;
      for (var i = 0; i < 64; i++) {
        if (theirs[i] == 1) s = game.move(s, 1, i)!;
      }
      expect(winnerOf(s), 1);
    });
  });

  group('memory match', () {
    const game = MemoryMatch();

    List<int> pair(GameState s, int face) => [
      for (var i = 0; i < 16; i++)
        if ((s['cards'] as List)[i] == face) i,
    ];

    test('a match is kept and the player goes again', () {
      final start = game.start(0, Random(2));
      final p = pair(start, 0);
      var s = game.move(start, 0, p[0])!;
      expect(game.move(s, 0, p[0]), isNull);
      s = game.move(s, 0, p[1])!;
      expect((s['found'] as List)[p[0]], 1);
      expect(turnOf(s), 0);
      expect(game.move(s, 0, p[0]), isNull);
    });

    test('a mismatch passes the turn and stays shown until the next flip', () {
      final start = game.start(0, Random(2));
      final a = pair(start, 0)[0], b = pair(start, 1)[0];
      var s = game.move(game.move(start, 0, a)!, 0, b)!;
      expect(turnOf(s), 1);
      expect(s['up'], [a, b]);
      s = game.move(s, 1, pair(start, 2)[0])!;
      expect(s['up'], hasLength(1));
    });

    test('finding all pairs ends the game', () {
      var s = game.start(0, Random(2));
      for (var face = 0; face < 8; face++) {
        for (final i in pair(s, face)) {
          s = game.move(s, 0, i)!;
        }
      }
      expect(winnerOf(s), 0);
    });
  });

  group('hangman', () {
    const game = Hangman();
    GameState word(String w) => {...game.start(0, Random(1)), 'word': w};

    test('every word is plain capitals', () {
      for (final w in hangmanWords) {
        expect(RegExp(r'^[A-Z]{4,}$').hasMatch(w), isTrue, reason: w);
      }
    });

    test('a hit scores per letter and keeps the turn, a miss passes it', () {
      var s = game.move(word('BANANA'), 0, 'A')!;
      expect(s['score'], [3, 0]);
      expect(turnOf(s), 0);
      expect(game.move(s, 0, 'A'), isNull);
      expect(game.move(s, 0, 'a'), isNull);
      s = game.move(s, 0, 'Z')!;
      expect(s['misses'], 1);
      expect(turnOf(s), 1);
    });

    test('solving the word ends the game for the higher score', () {
      var s = word('MANGO');
      for (final c in 'MANG'.split('')) {
        s = game.move(s, 0, c)!;
      }
      expect(winnerOf(s), isNull);
      expect(winnerOf(game.move(s, 0, 'O')!), 0);
    });

    test('seven misses end the game', () {
      var s = word('MANGO');
      for (final c in 'BCDEFHI'.split('')) {
        s = game.move(s, turnOf(s), c)!;
      }
      expect(winnerOf(s), drawn);
    });
  });
}
