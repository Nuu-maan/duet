import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'battleship.dart';
import 'checkers.dart';
import 'dots_and_boxes.dart';
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

  String _status(Object? value) {
    final room = asRoom(value);
    if (room == null) return 'Not started';
    final seat = seatOf(room, widget.uid);
    switch (room['status']) {
      case 'waiting':
        return seat == null ? 'Your friend is waiting' : 'Waiting for friend';
      case 'over':
        return 'Finished';
    }
    final turn = room['turn'];
    return turn == seat || turn == bothSeats ? 'Your turn' : "Friend's turn";
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
                      ? _status(rooms[game.id])
                      : '…';
                  final mine = status == 'Your turn';
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
