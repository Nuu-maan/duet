import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../appear.dart';
import '../art.dart';
import '../notifications.dart';
import '../pair.dart';
import 'game.dart';
import 'grid.dart';
import 'room.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.game,
    required this.uid,
    required this.names,
  });

  final Game game;
  final String uid;
  final Map<String, String> names;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _rng = Random();
  final _room = ValueNotifier<Room?>(null);
  final _state = ValueNotifier<GameState>(const {});
  final _seat = ValueNotifier<int?>(null);
  final _failed = ValueNotifier(false);
  StreamSubscription<DatabaseEvent>? _sub;

  Game get _game => widget.game;

  String get _friendUid =>
      widget.names.keys.firstWhere((k) => k != widget.uid, orElse: () => '');

  String get _friend => widget.names[_friendUid] ?? 'your friend';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _failed.value = false;
    _sub?.cancel();
    _sub = roomsRef().child(_game.id).onValue.listen((event) {
      final room = asRoom(event.snapshot.value);
      final seat = room == null ? null : seatOf(room, widget.uid);
      if (seat == null) {
        _change((v) => joinRoom(v, widget.uid, _game, _rng));
        return;
      }
      _state.value = stateOf(room!);
      _seat.value = seat;
      _room.value = room;
    }, onError: (_) => _failed.value = true);
  }

  void _change(Room? Function(Object?) change) {
    updateRoom(_game.id, change).catchError((_) => false);
  }

  void _play(Object? move) {
    final room = _room.value;
    final seat = _seat.value;
    if (room == null || seat == null || room['status'] != 'playing') return;
    if (_game.move(_state.value, seat, move) == null) return;
    HapticFeedback.selectionClick();
    updateRoom(_game.id, (v) => playMove(v, widget.uid, _game, move))
        .then((accepted) {
          if (accepted) {
            notifyFriend('move', {'game': _game.id, 'name': _game.name});
          }
        })
        .catchError((_) {});
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('The current game will be lost for both of you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (ok == true) _change((v) => rematch(v, _game, _rng, force: true));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _room.dispose();
    _state.dispose();
    _seat.dispose();
    _failed.dispose();
    super.dispose();
  }

  String _status(Room room, int seat) {
    if (room['status'] == 'waiting') return 'Waiting for $_friend to join';
    final state = _state.value;
    final winner = winnerOf(state);
    if (winner == drawn) return 'Draw';
    if (winner != null) return winner == seat ? 'You won!' : '$_friend won';
    final turn = turnOf(state);
    if (turn == bothSeats) return 'Both of you play';
    return turn == seat ? 'Your turn' : "$_friend's turn";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_game.name),
        actions: [
          IconButton(
            tooltip: 'Start over',
            icon: const Icon(Icons.restart_alt),
            onPressed: _restart,
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _failed,
          builder: (context, failed, _) {
            if (failed) {
              return Center(
                child: FilledButton(
                  onPressed: _listen,
                  child: const Text('Could not load. Try again'),
                ),
              );
            }
            return ValueListenableBuilder<int?>(
              valueListenable: _seat,
              builder: (context, seat, _) {
                if (seat == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  children: [
                    ValueListenableBuilder<Room?>(
                      valueListenable: _room,
                      builder: (context, room, _) {
                        final over = room!['status'] == 'over';
                        final status = _status(room, seat);
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: seatColor(theme.colorScheme, seat),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'You  ·  move ${room['turnNumber']}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _FriendOnline(uid: _friendUid, name: _friend),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  status,
                                  style: theme.textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (over) ...[
                                const SizedBox(height: 8),
                                Appear(
                                  child: Column(
                                    children: [
                                      Art(switch (winnerOf(_state.value)) {
                                        drawn => 'trophy_draw',
                                        final w when w == seat => 'trophy_won',
                                        _ => 'trophy_lost',
                                      }, size: 96),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: () => _change(
                                          (v) => rematch(v, _game, _rng),
                                        ),
                                        child: const Text('Play again'),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  _game.help,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _game.board(
                            context,
                            Board(state: _state, seat: seat, play: _play),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FriendOnline extends StatefulWidget {
  const _FriendOnline({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  State<_FriendOnline> createState() => _FriendOnlineState();
}

class _FriendOnlineState extends State<_FriendOnline> {
  late final Stream<DatabaseEvent>? _events = widget.uid.isEmpty
      ? null
      : membersRef().child('${widget.uid}/online').onValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DatabaseEvent>(
      stream: _events,
      builder: (context, snapshot) {
        final online = snapshot.data?.snapshot.value == true;
        return Text(
          '${widget.name} is ${online ? 'online' : 'offline'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: online
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
