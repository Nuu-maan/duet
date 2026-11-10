import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appear.dart';
import 'art.dart';
import 'daily.dart';
import 'daily_screen.dart';
import 'pair.dart';
import 'play_card.dart';
import 'theme.dart';

enum _Filter { all, myTurn, today }

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.uid,
    required this.names,
    required this.members,
  });

  final String uid;
  final List<Member> members;
  final Map<String, String> names;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // shortcut: shows the last 30 days only, add paging if older days matter
  final _events = dailyRef().orderByKey().limitToLast(30).onValue;
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = dayKey(DateTime.now());
    return FutureBuilder<QuestionBank>(
      future: questionBank,
      builder: (context, loaded) => StreamBuilder<DatabaseEvent>(
        stream: _events,
        builder: (context, snapshot) {
          final bank = loaded.data;
          if (snapshot.hasError || loaded.hasError) {
            return const MascotMessage(
              mascot: 'mascot_shocked',
              title: 'Could not load the inbox',
              body: 'Check your connection.',
            );
          }
          if (!snapshot.hasData || bank == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = inboxItems(
            snapshot.data!.snapshot.value,
            bank,
            widget.uid,
          );
          final waiting = all.where((i) => i.myTurn).length;
          final items = switch (_filter) {
            _Filter.all => all,
            _Filter.myTurn => all.where((i) => i.myTurn).toList(),
            _Filter.today => all.where((i) => i.day == today).toList(),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Inbox', style: theme.textTheme.headlineMedium),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final (filter, label) in [
                      (_Filter.all, 'All'),
                      (
                        _Filter.myTurn,
                        waiting == 0 ? 'Your turn' : 'Your turn  $waiting',
                      ),
                      (_Filter.today, 'Today'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const MascotMessage(
                        title: 'Nothing here yet',
                        body:
                            'Answer a question on Home and it lands here '
                            'for your friend.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: _PairStatus(
                              members: widget.members,
                              uid: widget.uid,
                              mine: item.mine != null,
                              theirs: item.theirs != null,
                            ),
                            title: Text(
                              item.question.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: item.myTurn
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              item.day == today ? 'Today' : item.day,
                            ),
                            trailing: item.myTurn
                                ? Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: scheme.tertiary,
                                    semanticLabel: 'Your turn',
                                  )
                                : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ThreadScreen(
                                  uid: widget.uid,
                                  names: widget.names,
                                  day: item.day,
                                  slot: item.slot,
                                  question: item.question,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    required this.uid,
    required this.names,
    required this.day,
    required this.slot,
    required this.question,
  });

  final String uid;
  final Map<String, String> names;
  final String day;
  final int slot;
  final DailyQuestion question;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late final _events = dailyRef(widget.day).onValue;
  final _answer = TextEditingController();
  bool _bumped = false;
  final _message = TextEditingController();

  String get _friendUid =>
      widget.names.keys.firstWhere((k) => k != widget.uid, orElse: () => '');

  String get _friend => widget.names[_friendUid] ?? 'your friend';

  @override
  void dispose() {
    _answer.dispose();
    _message.dispose();
    super.dispose();
  }

  void _failed(Object _) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not send.')));
  }

  void _respond(String value) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    submitAnswer(
      day: widget.day,
      uid: widget.uid,
      slot: widget.slot,
      value: value,
    ).catchError(_failed);
  }

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();
    sendMessage(
      day: widget.day,
      slot: widget.slot,
      uid: widget.uid,
      text: text,
    ).catchError(_failed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCard = theme.extension<Playful>()!.onCard;
    final question = widget.question;
    return Scaffold(
      appBar: AppBar(title: Text(_friend)),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const MascotMessage(
                mascot: 'mascot_shocked',
                title: 'Could not load',
                body: 'Check your connection.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final value = snapshot.data!.snapshot.value;
            final answers = answersOf(value);
            if (!_bumped &&
                widget.day == dayKey(DateTime.now()) &&
                bothAnswered(answers)) {
              _bumped = true;
              bumpStreak(widget.day).catchError((_) {});
            }
            final mine = answers[widget.uid]?[widget.slot];
            final theirs = answers[_friendUid]?[widget.slot];
            final chat = chatOf(value, widget.slot);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      PlayCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              question.text,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: onCard,
                              ),
                            ),
                            if (mine == null) ...[
                              const SizedBox(height: 24),
                              AnswerInputs(
                                question: question,
                                uid: widget.uid,
                                friendUid: _friendUid,
                                friend: _friend,
                                names: widget.names,
                                text: _answer,
                                onAnswer: _respond,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (theirs != null && mine == null)
                        _Bubble(
                          mine: false,
                          text: 'Answer to see what $_friend said',
                          icon: Icons.lock_outline,
                        ),
                      if (theirs != null && mine != null)
                        Appear(
                          child: _Bubble(
                            mine: false,
                            text: shownAnswer(question, theirs, widget.names),
                          ),
                        ),
                      if (mine != null)
                        _Bubble(
                          mine: true,
                          text: shownAnswer(question, mine, widget.names),
                        ),
                      if (mine != null && theirs == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Waiting for $_friend to answer.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final message in chat)
                        _Bubble(
                          mine: message.by == widget.uid,
                          text: message.text,
                        ),
                    ],
                  ),
                ),
                if (mine != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _message,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Send message…',
                              counterText: '',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Send',
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.text, this.icon});

  final bool mine;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mine
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PairStatus extends StatelessWidget {
  const _PairStatus({
    required this.members,
    required this.uid,
    required this.mine,
    required this.theirs,
  });

  final List<Member> members;
  final String uid;
  final bool mine;
  final bool theirs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget face(Member? member, bool done) => Stack(
      clipBehavior: Clip.none,
      children: [
        member == null
            ? const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 16),
              )
            : MemberAvatar(member: member, radius: 16, showOnline: false),
        if (done)
          Positioned(
            right: -4,
            top: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 16, color: scheme.tertiary),
            ),
          ),
      ],
    );
    return Semantics(
      label:
          '${mine ? 'You answered' : 'You have not answered'}, '
          '${theirs ? 'friend answered' : 'friend has not answered'}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            face(members.where((m) => m.uid == uid).firstOrNull, mine),
            const SizedBox(width: 4),
            face(members.where((m) => m.uid != uid).firstOrNull, theirs),
          ],
        ),
      ),
    );
  }
}
