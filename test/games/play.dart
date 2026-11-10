import 'package:duet/games/game.dart';

GameState playAll(Game game, GameState s, List<Object?> moves) {
  for (final m in moves) {
    s = game.move(s, turnOf(s), m)!;
  }
  return s;
}
