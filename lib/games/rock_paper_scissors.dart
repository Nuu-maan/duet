import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';

class RockPaperScissors extends Game {
  const RockPaperScissors();

  static const target = 3;
  static const names = ['Rock', 'Paper', 'Scissors'];
  static const icons = ['✊', '✋', '✌️'];

  @override
  String get id => 'rps';
  @override
  String get name => 'Rock paper scissors';
  @override
  IconData get icon => Icons.back_hand;
  @override
  String get help =>
      'Pick one. Your friend cannot see it until you both pick. First to 3 wins.';

  @override
  GameState start(int first, Random rng) => {
    'turn': bothSeats,
    'picks': [-1, -1],
    'last': [-1, -1],
    'score': [0, 0],
  };

  @override
  bool waitsFor(GameState s, int seat) => (s['picks'] as List)[seat] == -1;

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null) return null;
    if (m is! int || m < 0 || m > 2) return null;
    if ((s['picks'] as List)[seat] != -1) return null;
    final next = copyState(s);
    final picks = next['picks'] as List;
    picks[seat] = m;
    if (picks.contains(-1)) return next;
    final score = next['score'] as List;
    final diff = ((picks[0] as int) - (picks[1] as int) + 3) % 3;
    if (diff != 0) score[diff == 1 ? 0 : 1] += 1;
    next['last'] = picks;
    next['picks'] = [-1, -1];
    final leader = score.indexOf(target);
    if (leader != -1) next['winner'] = leader;
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<GameState>(
      valueListenable: b.state,
      builder: (context, s, _) {
        final me = b.seat, them = 1 - b.seat;
        final score = s['score'] as List, last = s['last'] as List;
        final picked = (s['picks'] as List)[me] as int;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You ${score[me]}  –  ${score[them]} ${b.friend}',
              style: theme.textTheme.headlineSmall,
            ),
            Text('First to $target', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (last[me] != -1)
              Text(
                'Last round: you ${names[last[me] as int].toLowerCase()}, '
                '${b.friend} ${names[last[them] as int].toLowerCase()}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: 24),
            if (picked != -1)
              Text(
                'You picked ${names[picked].toLowerCase()}. '
                'Waiting for ${b.friend}.',
                textAlign: TextAlign.center,
              )
            else if (winnerOf(s) == null)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    FilledButton.tonal(
                      onPressed: () => b.play(i),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 112),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(icons[i], style: theme.textTheme.displaySmall),
                            Text(names[i]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
