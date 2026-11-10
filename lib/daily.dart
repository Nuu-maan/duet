import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime _utcDay(String day) {
  final d = DateTime.parse(day);
  return DateTime.utc(d.year, d.month, d.day);
}

String previousDay(String day) =>
    dayKey(_utcDay(day).subtract(const Duration(days: 1)));

int questionIndex(String day, int count) =>
    _utcDay(day).difference(DateTime.utc(2026)).inDays % count;

int shownStreak(Object? streak, String today) {
  if (streak is! Map) return 0;
  final lastDay = streak['lastDay'];
  final count = streak['count'];
  if (count is! int) return 0;
  return lastDay == today || lastDay == previousDay(today) ? count : 0;
}

/// The home screen shows nothing until two days in a row are done.
int displayStreak(Object? streak, String today) {
  final run = shownStreak(streak, today);
  return run >= 2 ? run : 0;
}

int bestStreak(Object? streak) =>
    streak is Map && streak['best'] is int ? streak['best'] as int : 0;

Set<String> streakDays(Object? streak) {
  final days = streak is Map ? streak['days'] : null;
  if (days is! Map) return const {};
  return {
    for (final key in days.keys)
      if (key is String) key,
  };
}

/// The days of the run that is still alive, newest first.
Set<String> currentRun(Object? streak, String today) {
  final length = shownStreak(streak, today);
  if (length == 0) return const {};
  var day = (streak as Map)['lastDay'] as String;
  final run = <String>{};
  for (var i = 0; i < length; i++) {
    run.add(day);
    day = previousDay(day);
  }
  return run;
}

Map<String, Object>? nextStreak(Object? streak, String today) {
  if (streak is Map && streak['lastDay'] == today) return null;
  final count = shownStreak(streak, today) + 1;
  return {
    'count': count,
    'lastDay': today,
    'best': max(bestStreak(streak), count),
    'days': {for (final day in streakDays(streak)) day: true, today: true},
  };
}

enum QuestionType { text, who, pick }

class DailyQuestion {
  const DailyQuestion(this.type, this.text, [this.options = const []]);

  final QuestionType type;
  final String text;
  final List<String> options;
}

const questionsPerDay = 3;

class QuestionBank {
  QuestionBank(this.text, this.who, this.pick);

  factory QuestionBank.fromJson(Map<String, dynamic> json) => QuestionBank(
    (json['text'] as List).cast<String>(),
    (json['who'] as List).cast<String>(),
    [for (final p in json['pick'] as List) (p as List).cast<String>()],
  );

  final List<String> text;
  final List<String> who;
  final List<List<String>> pick;

  // shortcut: questions are recomputed from the date, so editing the lists
  // changes what past days show; store the text per day if that matters
  List<DailyQuestion> forDay(String day) {
    final choice = pick[questionIndex(day, pick.length)];
    return [
      DailyQuestion(QuestionType.text, text[questionIndex(day, text.length)]),
      DailyQuestion(QuestionType.who, who[questionIndex(day, who.length)]),
      DailyQuestion(QuestionType.pick, choice[0], choice.sublist(1)),
    ];
  }
}

final Future<QuestionBank> questionBank = rootBundle
    .loadString('assets/questions.json')
    .then(
      (text) => QuestionBank.fromJson(jsonDecode(text) as Map<String, dynamic>),
    );

DatabaseReference dailyRef([String? day]) {
  final ref = FirebaseDatabase.instance.ref('pair/daily');
  return day == null ? ref : ref.child(day);
}

DatabaseReference streakRef() => FirebaseDatabase.instance.ref('pair/streak');

// Older builds stored a skip as an empty string; it now counts as unanswered.
String? _answer(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, List<String?>> answersOf(Object? dayValue) {
  final answers = dayValue is Map ? dayValue['answers'] : null;
  if (answers is! Map) return const {};
  return {
    for (final e in answers.entries)
      if (e.key is String && e.value is Map)
        e.key as String: [
          for (var i = 0; i < questionsPerDay; i++)
            _answer((e.value as Map)['q$i']) != null
                ? (e.value as Map)['q$i'] as String
                : null,
        ],
  };
}

bool hasAnswered(List<String?>? answers) =>
    answers != null && answers.any((a) => a != null);

bool bothAnswered(Map<String, List<String?>> answers) =>
    answers.length >= 2 && answers.values.every(hasAnswered);

String shownAnswer(
  DailyQuestion question,
  String value,
  Map<String, String> names,
) {
  if (question.type == QuestionType.who) return names[value] ?? 'Your friend';
  return value;
}

Future<void> submitAnswer({
  required String day,
  required String uid,
  required int slot,
  required String value,
}) => dailyRef(day).update({'answers/$uid/q$slot': value});

Future<void> bumpStreak(String today) => streakRef().runTransaction((current) {
  final next = nextStreak(current, today);
  return next == null ? Transaction.abort() : Transaction.success(next);
});

class InboxItem {
  const InboxItem({
    required this.day,
    required this.slot,
    required this.question,
    required this.mine,
    required this.theirs,
  });

  final String day;
  final int slot;
  final DailyQuestion question;
  final String? mine;
  final String? theirs;

  bool get myTurn => mine == null && theirs != null;
}

List<String?> _friendAnswers(Map<String, List<String?>> answers, String uid) {
  for (final e in answers.entries) {
    if (e.key != uid) return e.value;
  }
  return List.filled(questionsPerDay, null);
}

/// Newest day first. A question is in the inbox once either person answers.
List<InboxItem> inboxItems(Object? daily, QuestionBank bank, String uid) {
  final days = <String, Object?>{
    if (daily is Map)
      for (final e in daily.entries)
        if (e.key is String && DateTime.tryParse(e.key as String) != null)
          e.key as String: e.value,
  };
  final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
  final items = <InboxItem>[];
  for (final day in keys) {
    final answers = answersOf(days[day]);
    final mine = answers[uid] ?? const [null, null, null];
    final theirs = _friendAnswers(answers, uid);
    final asked = bank.forDay(day);
    for (var slot = 0; slot < questionsPerDay; slot++) {
      if (mine[slot] == null && theirs[slot] == null) continue;
      items.add(
        InboxItem(
          day: day,
          slot: slot,
          question: asked[slot],
          mine: mine[slot],
          theirs: theirs[slot],
        ),
      );
    }
  }
  return items;
}

class ChatMessage {
  const ChatMessage(this.by, this.text);

  final String by;
  final String text;
}

List<ChatMessage> chatOf(Object? dayValue, int slot) {
  final chat = dayValue is Map ? dayValue['chat'] : null;
  final thread = chat is Map ? chat['q$slot'] : null;
  if (thread is! Map) return const [];
  final entries = thread.entries.where((e) => e.key is String).toList()
    ..sort((a, b) => (a.key as String).compareTo(b.key as String));
  return [
    for (final e in entries)
      if (e.value case {'by': final String by, 'text': final String text})
        ChatMessage(by, text),
  ];
}

Future<void> sendMessage({
  required String day,
  required int slot,
  required String uid,
  required String text,
}) =>
    dailyRef(day)
        .child('chat/q$slot')
        .push()
        .set({'by': uid, 'text': text, 'at': ServerValue.timestamp});
