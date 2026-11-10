import 'dart:math';

import 'package:flutter/material.dart';

import 'game.dart';

const hangmanWords = [
  'ADVENTURE',
  'AIRPORT',
  'BALCONY',
  'BANANA',
  'BICYCLE',
  'BISCUIT',
  'BLANKET',
  'BRIDGE',
  'BUTTERFLY',
  'CAMERA',
  'CANDLE',
  'CAPTAIN',
  'CARPET',
  'CHICKEN',
  'CHIMNEY',
  'CHOCOLATE',
  'CIRCUS',
  'COCONUT',
  'COFFEE',
  'COMPASS',
  'CRICKET',
  'CURTAIN',
  'DIAMOND',
  'DOLPHIN',
  'DRAGON',
  'ELEPHANT',
  'ENGINE',
  'FESTIVAL',
  'FIREWORK',
  'FOREST',
  'FRIEND',
  'GARDEN',
  'GIRAFFE',
  'GUITAR',
  'HAMMER',
  'HARVEST',
  'HELMET',
  'HOLIDAY',
  'HORIZON',
  'ISLAND',
  'JACKET',
  'JOURNEY',
  'JUNGLE',
  'KITCHEN',
  'LADDER',
  'LANTERN',
  'LIBRARY',
  'LIGHTHOUSE',
  'MAGNET',
  'MANGO',
  'MARKET',
  'MIRROR',
  'MONKEY',
  'MONSOON',
  'MOUNTAIN',
  'MUSEUM',
  'NOTEBOOK',
  'OCEAN',
  'ORANGE',
  'PAINTER',
  'PANCAKE',
  'PARROT',
  'PEACOCK',
  'PENCIL',
  'PEPPER',
  'PICNIC',
  'PILLOW',
  'PIRATE',
  'PLANET',
  'POCKET',
  'PUMPKIN',
  'PUZZLE',
  'RAINBOW',
  'RIVER',
  'ROCKET',
  'SAMOSA',
  'SANDWICH',
  'SCOOTER',
  'SHADOW',
  'SILVER',
  'SPIDER',
  'STADIUM',
  'STATION',
  'SUMMER',
  'SUNRISE',
  'TEACHER',
  'TEMPLE',
  'THUNDER',
  'TICKET',
  'TIGER',
  'TOMATO',
  'TRACTOR',
  'TREASURE',
  'TUNNEL',
  'UMBRELLA',
  'VILLAGE',
  'VOLCANO',
  'WEDDING',
  'WHISTLE',
  'WINDOW',
  'WINTER',
  'WIZARD',
];

class Hangman extends Game {
  const Hangman();

  static const maxMisses = 7;

  @override
  String get id => 'hangman';
  @override
  String get name => 'Hangman';
  @override
  IconData get icon => Icons.abc;
  @override
  String get help =>
      'Take turns guessing letters. Each letter found scores a point.';

  @override
  GameState start(int first, Random rng) => {
    'turn': first,
    'word': hangmanWords[rng.nextInt(hangmanWords.length)],
    'guessed': '',
    'score': [0, 0],
    'misses': 0,
  };

  @override
  GameState? move(GameState s, int seat, Object? m) {
    if (winnerOf(s) != null || turnOf(s) != seat) return null;
    if (m is! String || !RegExp(r'^[A-Z]$').hasMatch(m)) return null;
    final guessed = s['guessed'] as String;
    if (guessed.contains(m)) return null;
    final next = copyState(s);
    final word = next['word'] as String;
    final score = next['score'] as List;
    next['guessed'] = guessed + m;
    final hits = m.allMatches(word).length;
    if (hits > 0) {
      score[seat] += hits;
    } else {
      next['misses'] = (next['misses'] as int) + 1;
      next['turn'] = 1 - seat;
    }
    final solved = word.split('').every((next['guessed'] as String).contains);
    if (solved || next['misses'] == maxMisses) {
      next['winner'] = score[0] == score[1]
          ? drawn
          : (score[0] as int) > (score[1] as int)
          ? 0
          : 1;
    }
    return next;
  }

  @override
  Widget board(BuildContext context, Board b) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<GameState>(
      valueListenable: b.state,
      builder: (context, s, _) {
        final word = s['word'] as String, guessed = s['guessed'] as String;
        final score = s['score'] as List;
        final over = winnerOf(s) != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You ${score[b.seat]}  –  ${score[1 - b.seat]} Friend',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: 120,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _GallowsPainter(
                    s['misses'] as int,
                    scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FittedBox(
              child: Text(
                [
                  for (final c in word.split(''))
                    over || guessed.contains(c) ? c : '_',
                ].join(' '),
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      onPressed: over || guessed.contains(c)
                          ? null
                          : () => b.play(c),
                      child: Text(c),
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

class _GallowsPainter extends CustomPainter {
  _GallowsPainter(this.misses, this.color);

  final int misses;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset p(double x, double y) => Offset(x * w, y * h);
    canvas.drawLine(p(0.1, 0.95), p(0.6, 0.95), paint);
    canvas.drawLine(p(0.25, 0.95), p(0.25, 0.05), paint);
    canvas.drawLine(p(0.25, 0.05), p(0.65, 0.05), paint);
    final parts = <void Function()>[
      () => canvas.drawLine(p(0.65, 0.05), p(0.65, 0.18), paint),
      () => canvas.drawCircle(p(0.65, 0.27), 0.09 * w, paint),
      () => canvas.drawLine(p(0.65, 0.36), p(0.65, 0.62), paint),
      () => canvas.drawLine(p(0.65, 0.42), p(0.52, 0.54), paint),
      () => canvas.drawLine(p(0.65, 0.42), p(0.78, 0.54), paint),
      () => canvas.drawLine(p(0.65, 0.62), p(0.54, 0.8), paint),
      () => canvas.drawLine(p(0.65, 0.62), p(0.76, 0.8), paint),
    ];
    for (final part in parts.take(misses)) {
      part();
    }
  }

  @override
  bool shouldRepaint(_GallowsPainter old) =>
      old.misses != misses || old.color != color;
}
