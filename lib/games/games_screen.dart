import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'battleship.dart';
import 'checkers.dart';
import 'dots_and_boxes.dart';
import '../draw_screen.dart';
import '../drawing.dart';
import 'game.dart';
import 'game_screen.dart';
import 'hangman.dart';
import 'line_games.dart';
import '../play_card.dart';
import '../theme.dart';
import 'memory_match.dart';
import 'reversi.dart';
import 'rock_paper_scissors.dart';
import 'room.dart';
import 'tic_tac_toe.dart';

const List<Game> games = [
  TicTacToe(),
  FourInARow(),
  DotsAndBoxes(),
  Reversi(),
  Gomoku(),
  RockPaperScissors(),
  Battleship(),
  MemoryMatch(),
  Checkers(),
  Hangman(),
];

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.uid, required this.names});

  final String uid;
  final Map<String, String> names;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final _events = roomsRef().onValue;

  String _status(Game game, Object? value) {
    final room = asRoom(value);
    if (room == null) return 'Not started';
    final seat = seatOf(room, widget.uid);
    switch (room['status']) {
      case 'waiting':
        return seat == null ? 'Tap to join' : 'Waiting for friend';
      case 'over':
        return 'Finished';
    }
    if (seat == null) return 'In progress';
    return game.waitsFor(stateOf(room), seat) ? 'Your turn' : "Friend's turn";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    return StreamBuilder<DatabaseEvent>(
      stream: _events,
      builder: (context, snapshot) {
        final value = snapshot.data?.snapshot.value;
        final rooms = value is Map ? value : const {};
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Games', style: theme.textTheme.headlineMedium),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _DrawTile(uid: widget.uid)),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 184,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final game = games[i];
                  final status = snapshot.hasError
                      ? 'Status unavailable'
                      : snapshot.hasData
                      ? _status(game, rooms[game.id])
                      : '…';
                  final mine = status == 'Your turn' || status == 'Tap to join';
                  return PlayCard(
                    colorIndex: i,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(
                          game: game,
                          uid: widget.uid,
                          names: widget.names,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(game.icon, size: 44),
                        const Spacer(),
                        Text(
                          game.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: playful.onCard,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: mine
                                ? theme.colorScheme.tertiary
                                : playful.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: playful.onCard,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The shared drawing board, shown as one big tile above the games.
class _DrawTile extends StatefulWidget {
  const _DrawTile({required this.uid});

  final String uid;

  @override
  State<_DrawTile> createState() => _DrawTileState();
}

class _DrawTileState extends State<_DrawTile> {
  final _events = drawingRef().child('preview').onValue;
  String? _encoded;
  Uint8List? _png;

  Uint8List? _decode(Object? value) {
    if (value is! String || value.isEmpty) return null;
    if (value != _encoded) {
      _encoded = value;
      try {
        _png = base64Decode(value);
      } on FormatException {
        _png = null;
      }
    }
    return _png;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCard = theme.extension<Playful>()!.onCard;
    return AspectRatio(
      aspectRatio: 1,
      child: PlayCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DrawScreen(uid: widget.uid)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  const Icon(Icons.brush_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drawing board',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onCard,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: boardColor,
                  child: StreamBuilder<DatabaseEvent>(
                    stream: _events,
                    builder: (context, snapshot) {
                      final png = _decode(snapshot.data?.snapshot.value);
                      if (png == null) {
                        return Center(
                          child: Text(
                            'Tap to draw together',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: onCard,
                            ),
                          ),
                        );
                      }
                      return Image.memory(
                        png,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        semanticLabel: 'The current drawing',
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
