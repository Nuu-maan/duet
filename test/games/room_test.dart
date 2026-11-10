import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:duet/games/game.dart';
import 'package:duet/games/room.dart';
import 'package:duet/games/tic_tac_toe.dart';

void main() {
  const game = TicTacToe();
  final rng = Random(1);

  Room twoPlayers() =>
      joinRoom(joinRoom(null, 'a', game, rng), 'b', game, rng)!;

  test('first player waits in seat 0, second takes seat 1 and play starts', () {
    final one = joinRoom(null, 'a', game, rng)!;
    expect(one['status'], 'waiting');
    expect(seatOf(one, 'a'), 0);

    final two = joinRoom(one, 'b', game, rng)!;
    expect(two['status'], 'playing');
    expect(seatOf(two, 'b'), 1);
    expect(two['turnNumber'], 0);
  });

  test('rejoining changes nothing, so the same game is resumed', () {
    final room = playMove(twoPlayers(), 'a', game, 4)!;
    expect(joinRoom(room, 'a', game, rng), isNull);
    expect(joinRoom(room, 'b', game, rng), isNull);
    expect(joinRoom(room, 'stranger', game, rng), isNull);
  });

  test('no moves while waiting for the second player', () {
    expect(playMove(joinRoom(null, 'a', game, rng), 'a', game, 0), isNull);
  });

  test('out-of-turn and unseated moves are rejected', () {
    final room = twoPlayers();
    expect(playMove(room, 'b', game, 0), isNull);
    expect(playMove(room, 'stranger', game, 0), isNull);

    final next = playMove(room, 'a', game, 0)!;
    expect(next['turn'], 1);
    expect(next['turnNumber'], 1);
    expect(playMove(next, 'a', game, 1), isNull);
    expect(playMove(next, 'b', game, 1), isNotNull);
  });

  test('a win ends the room and play again swaps who starts', () {
    Object? room = twoPlayers();
    for (final (uid, cell) in [('a', 0), ('b', 3), ('a', 1), ('b', 4)]) {
      room = playMove(room, uid, game, cell);
    }
    expect(rematch(room, game, rng), isNull);

    final over = playMove(room, 'a', game, 2)!;
    expect(over['status'], 'over');
    expect(winnerOf(stateOf(over)), 0);
    expect(playMove(over, 'b', game, 5), isNull);

    final again = rematch(over, game, rng)!;
    expect(again['status'], 'playing');
    expect(again['turn'], 1);
    expect(again['turnNumber'], 0);
    expect(rematch(room, game, rng, force: true), isNotNull);
  });

  test('state survives the shape the database hands back', () {
    final raw = <Object?, Object?>{
      ...twoPlayers(),
      'players': <Object?, Object?>{'a': 0, 'b': 1},
    };
    expect(playMove(raw, 'a', game, 8), isNotNull);
    expect(asRoom({'players': 3}), isNull);
  });
}
