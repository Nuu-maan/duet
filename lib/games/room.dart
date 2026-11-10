import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import '../pair.dart';
import 'game.dart';

typedef Room = Map<String, dynamic>;

Room? asRoom(Object? value) {
  if (value is! Map || value['players'] is! Map || value['state'] is! String) {
    return null;
  }
  return Room.from(value)
    ..['players'] = Map<String, dynamic>.from(value['players'] as Map);
}

GameState stateOf(Room room) =>
    jsonDecode(room['state'] as String) as GameState;

int? seatOf(Room room, String uid) => (room['players'] as Map)[uid] as int?;

Room _fresh(Game game, int first, Random rng) {
  final state = game.start(first, rng);
  return {
    'first': first,
    'state': jsonEncode(state),
    'turn': turnOf(state),
    'turnNumber': 0,
  };
}

Room? joinRoom(Object? value, String uid, Game game, Random rng) {
  final room = asRoom(value);
  if (room == null) {
    return {
      ..._fresh(game, 0, rng),
      'status': 'waiting',
      'players': {uid: 0},
    };
  }
  final players = room['players'] as Map<String, dynamic>;
  if (players.containsKey(uid) || players.length >= 2) return null;
  return {
    ...room,
    'status': 'playing',
    'players': {...players, uid: 1 - (players.values.first as int)},
  };
}

Room? playMove(Object? value, String uid, Game game, Object? move) {
  final room = asRoom(value);
  if (room == null || room['status'] != 'playing') return null;
  final seat = seatOf(room, uid);
  if (seat == null) return null;
  final next = game.move(stateOf(room), seat, move);
  if (next == null) return null;
  return {
    ...room,
    'state': jsonEncode(next),
    'turn': turnOf(next),
    'turnNumber': (room['turnNumber'] as int) + 1,
    'status': winnerOf(next) == null ? 'playing' : 'over',
  };
}

Room? rematch(Object? value, Game game, Random rng, {bool force = false}) {
  final room = asRoom(value);
  if (room == null || (room['players'] as Map).length < 2) return null;
  if (!force && room['status'] != 'over') return null;
  return {
    ...room,
    ..._fresh(game, 1 - (room['first'] as int), rng),
    'status': 'playing',
  };
}

DatabaseReference roomsRef() => FirebaseDatabase.instance.ref('$dbRoot/rooms');

Future<bool> updateRoom(
  String gameId,
  Room? Function(Object? value) change,
) async {
  final result = await roomsRef().child(gameId).runTransaction((value) {
    final next = change(value);
    return next == null ? Transaction.abort() : Transaction.success(next);
  });
  return result.committed;
}
