import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appear.dart';
import 'art.dart';
import 'confetti.dart';
import 'daily.dart';
import 'play_card.dart';
import 'theme.dart';

const _noAnswers = <String?>[null, null, null];

const _typeLabels = {
  QuestionType.text: '✍️  In your words',
  QuestionType.who: '👀  Who is more likely',
  QuestionType.pick: '⚡  This or that',
};

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key, required this.uid, required this.names});

  final String uid;
  final Map<String, String> names;

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen>
    with SingleTickerProviderStateMixin {
  final _day = dayKey(DateTime.now());
  late Stream<DatabaseEvent> _events = dailyRef(_day).onValue;
  final _pages = PageController();
  final _page = ValueNotifier(0);
  final _text = TextEditingController();
  late final _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _bumped = false;

  String get _friendUid =>
      widget.names.keys.firstWhere((k) => k != widget.uid, orElse: () => '');

  String get _friend => widget.names[_friendUid] ?? 'your friend';

  @override
  void dispose() {
    _pages.dispose();
    _page.dispose();
    _text.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    FocusScope.of(context).unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _answer(int slot, String value) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    submitAnswer(
      day: _day,
      uid: widget.uid,
      slot: slot,
      value: value,
    ).catchError((_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your answer.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playful = theme.extension<Playful>()!;
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily challenge'),
        actions: [
          IconButton(
            tooltip: 'Past days',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    HistoryScreen(uid: widget.uid, names: widget.names),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: FutureBuilder<QuestionBank>(
              future: questionBank,
              builder: (context, loaded) {
                if (loaded.hasError) {
                  return const MascotMessage(
                    mascot: 'mascot_shocked',
                    title: 'No questions found',
                  );
                }
                final bank = loaded.data;
                if (bank == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final today = bank.forDay(_day);
                return StreamBuilder<DatabaseEvent>(
                  stream: _events,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return MascotMessage(
                        mascot: 'mascot_shocked',
                        title: 'Could not load',
                        actionLabel: 'Try again',
                        onAction: () =>
                            setState(() => _events = dailyRef(_day).onValue),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final answers = answersOf(snapshot.data!.snapshot.value);
                    final mine = answers[widget.uid] ?? _noAnswers;
                    final theirs = answers[_friendUid] ?? _noAnswers;
                    final answered = mine.where((a) => a != null).length;
                    if (bothAnswered(answers) && !_bumped) {
                      _bumped = true;
                      bumpStreak(_day).catchError((_) {});
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _page,
                            builder: (context, page, _) => Semantics(
                              label: '$answered of $questionsPerDay answered',
                              child: Row(
                                children: [
                                  for (var i = 0; i < questionsPerDay; i++)
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        height: i == page ? 14 : 8,
                                        decoration: BoxDecoration(
                                          color: mine[i] != null
                                              ? scheme.tertiary
                                              : i == page
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pages,
                            itemCount: questionsPerDay + 1,
                            onPageChanged: (i) {
                              _page.value = i;
                              if (i == questionsPerDay &&
                                  answered == questionsPerDay &&
                                  !still) {
                                HapticFeedback.heavyImpact();
                                _confetti.forward(from: 0);
                              }
                            },
                            itemBuilder: (context, i) => i == questionsPerDay
                                ? _FinishPage(
                                    answered: answered,
                                    onDone: () => Navigator.of(context).pop(),
                                    onBack: () => _goTo(
                                      mine.indexWhere((a) => a == null),
                                    ),
                                  )
                                : _QuestionPage(
                                    index: i,
                                    question: today[i],
                                    mine: mine[i],
                                    theirs: theirs[i],
                                    uid: widget.uid,
                                    friendUid: _friendUid,
                                    friend: _friend,
                                    names: widget.names,
                                    text: _text,
                                    onAnswer: (value) => _answer(i, value),
                                    onNext: () => _goTo(i + 1),
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
          if (!still)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ConfettiPainter(_confetti, [
                      ...playful.cards,
                      playful.paper,
                      scheme.tertiary,
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.index,
    required this.question,
    required this.mine,
    required this.theirs,
    required this.uid,
    required this.friendUid,
    required this.friend,
    required this.names,
    required this.text,
    required this.onAnswer,
    required this.onNext,
  });

  final int index;
  final DailyQuestion question;
  final String? mine;
  final String? theirs;
  final String uid;
  final String friendUid;
  final String friend;
  final Map<String, String> names;
  final TextEditingController text;
  final void Function(String value) onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    final onCard = playful.onCard;
    final answered = mine != null;
    final last = index == questionsPerDay - 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PlayCard(
              colorIndex: index,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: playful.paper,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  _typeLabels[question.type]!,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: onCard,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Art(
                          answered ? 'mascot_excited' : 'mascot_hi',
                          size: 64,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(
                          question.text,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: onCard,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(playful.card(index), onCard, 0.15),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: !answered
                          ? AnswerInputs(
                              question: question,
                              uid: uid,
                              friendUid: friendUid,
                              friend: friend,
                              names: names,
                              text: text,
                              onAnswer: onAnswer,
                            )
                          : Appear(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AnswerLine(
                                    name: 'You',
                                    value: shownAnswer(question, mine!, names),
                                  ),
                                  const SizedBox(height: 8),
                                  if (theirs != null)
                                    _AnswerLine(
                                      name: friend,
                                      value: shownAnswer(
                                        question,
                                        theirs!,
                                        names,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Sent! Waiting for $friend to answer.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: onCard),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (answered)
            FilledButton(
              onPressed: onNext,
              child: Text(last ? 'Finish' : 'Next question'),
            )
          else ...[
            if (theirs != null)
              Text(
                '$friend has answered. Answer to see it!',
                textAlign: TextAlign.center,
              ),
            TextButton(onPressed: onNext, child: const Text('Skip')),
          ],
        ],
      ),
    );
  }
}

class _FinishPage extends StatelessWidget {
  const _FinishPage({
    required this.answered,
    required this.onDone,
    required this.onBack,
  });

  final int answered;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final all = answered == questionsPerDay;
    return Appear(
      child: MascotMessage(
        mascot: all ? 'mascot_excited' : 'mascot_hi',
        title: all
            ? 'All three done!'
            : '$answered of $questionsPerDay answered',
        body: all
            ? 'Come back tomorrow for three new ones.'
            : 'Skipped ones are not sent. You can still answer them today.',
        actionLabel: all ? 'Done' : 'Answer the rest',
        onAction: all ? onDone : onBack,
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.avatar = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    final radius = BorderRadius.circular(20);
    final ink = selected ? playful.paper : playful.onCard;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? playful.onCard : playful.paper,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: playful.onCard, width: 2),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avatar) ...[
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: playful.card(0),
                      foregroundColor: playful.onCard,
                      child: selected
                          ? const Icon(Icons.check_rounded)
                          : Text(label.characters.first.toUpperCase()),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: ink),
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

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: playful.paper,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.labelLarge?.copyWith(
                color: playful.onCard,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: playful.onCard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.uid, required this.names});

  final String uid;
  final Map<String, String> names;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // shortcut: shows the last 90 days only, add paging if older days matter
  final _events = dailyRef().orderByKey().limitToLast(90).onValue;
  final _today = dayKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Past days')),
      body: SafeArea(
        child: FutureBuilder<QuestionBank>(
          future: questionBank,
          builder: (context, loaded) => StreamBuilder<DatabaseEvent>(
            stream: _events,
            builder: (context, snapshot) {
              final bank = loaded.data;
              if (snapshot.hasError || loaded.hasError) {
                return const MascotMessage(
                  mascot: 'mascot_shocked',
                  title: 'Could not load past days',
                );
              }
              if (!snapshot.hasData || bank == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final value = snapshot.data!.snapshot.value;
              final days = value is Map
                  ? (value.entries
                        .where((e) => e.key is String && e.key != _today)
                        .toList()
                      ..sort(
                        (a, b) => (b.key as String).compareTo(a.key as String),
                      ))
                  : const <MapEntry<Object?, Object?>>[];
              if (days.isEmpty) {
                return const MascotMessage(
                  title: 'No past days yet',
                  body: 'Answered questions will show up here.',
                );
              }
              return ListView.builder(
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final day = days[i].key as String;
                  final asked = bank.forDay(day);
                  final answers = answersOf(days[i].value);
                  return ExpansionTile(
                    title: Text(day),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (var q = 0; q < questionsPerDay; q++) ...[
                        Text(asked[q].text, style: theme.textTheme.titleMedium),
                        for (final e in answers.entries)
                          if (e.value[q] != null)
                            Text(
                              '${e.key == widget.uid ? 'You' : widget.names[e.key] ?? 'Friend'}: '
                              '${shownAnswer(asked[q], e.value[q]!, widget.names)}',
                            ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnswerInputs extends StatefulWidget {
  const AnswerInputs({
    super.key,
    required this.question,
    required this.uid,
    required this.friendUid,
    required this.friend,
    required this.names,
    required this.text,
    required this.onAnswer,
  });

  final DailyQuestion question;
  final String uid;
  final String friendUid;
  final String friend;
  final Map<String, String> names;
  final TextEditingController text;
  final void Function(String value) onAnswer;

  @override
  State<AnswerInputs> createState() => _AnswerInputsState();
}

class _AnswerInputsState extends State<AnswerInputs> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;
    if (question.type == QuestionType.text) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.text,
            minLines: 2,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Type here…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final value = widget.text.text.trim();
              if (value.isNotEmpty) widget.onAnswer(value);
            },
            child: const Text('Send'),
          ),
        ],
      );
    }
    final who = question.type == QuestionType.who;
    final noFriend = widget.friendUid.isEmpty;
    final choices = who
        ? [
            (widget.uid, widget.names[widget.uid] ?? 'Me'),
            (
              noFriend ? 'friend' : widget.friendUid,
              noFriend ? 'My friend' : widget.friend,
            ),
          ]
        : [for (final option in question.options) (option, option)];
    final tiles = [
      for (final (value, label) in choices)
        _Choice(
          label: label,
          avatar: who,
          selected: _picked == value,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _picked = value);
          },
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (who)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ],
          )
        else ...[
          tiles[0],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'OR',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.extension<Playful>()!.onCard,
              ),
            ),
          ),
          tiles[1],
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _picked == null ? null : () => widget.onAnswer(_picked!),
          child: Text(_picked == null ? 'Pick one to answer' : 'Lock in'),
        ),
      ],
    );
  }
}
