import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:duet/games/game.dart';
import 'package:duet/games/tic_tac_toe.dart';

import 'play.dart';

void main() {
  const game = TicTacToe();
  GameState start() => game.start(0, Random(1));

  test('rejects occupied cells, bad input and the wrong seat', () {
    final s = game.move(start(), 0, 4)!;
    expect(game.move(s, 1, 4), isNull);
    expect(game.move(s, 0, 0), isNull);
    expect(game.move(s, 1, 9), isNull);
    expect(game.move(s, 1, 'x'), isNull);
  });

  test('does not mutate the state it was given', () {
    final s = start();
    game.move(s, 0, 0);
    expect(s['b'], List.filled(9, 0));
  });

  test('detects row, column and diagonal wins', () {
    expect(winnerOf(playAll(game, start(), [0, 3, 1, 4, 2])), 0);
    expect(winnerOf(playAll(game, start(), [0, 1, 3, 4, 8, 7])), 1);
    expect(winnerOf(playAll(game, start(), [0, 1, 4, 2, 8])), 0);
  });

  test('full board without a line is a draw', () {
    final s = playAll(game, start(), [0, 1, 2, 4, 3, 5, 7, 6, 8]);
    expect(winnerOf(s), drawn);
  });

  test('no moves after the game is over', () {
    final s = playAll(game, start(), [0, 3, 1, 4, 2]);
    expect(game.move(s, 1, 5), isNull);
  });
}
