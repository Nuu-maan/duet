import 'package:flutter_test/flutter_test.dart';
import 'package:duet/daily.dart';

void main() {
  test('dayKey pads month and day', () {
    expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('previousDay crosses month and year', () {
    expect(previousDay('2026-03-01'), '2026-02-28');
    expect(previousDay('2027-01-01'), '2026-12-31');
  });

  test('question index is stable per day, advances daily and wraps', () {
    expect(questionIndex('2026-11-10', 114), questionIndex('2026-11-10', 114));
    expect(
      questionIndex('2026-11-11', 114),
      (questionIndex('2026-11-10', 114) + 1) % 114,
    );
    expect(questionIndex('2026-01-04', 3), 0);
    expect(questionIndex('2025-12-31', 3), 2);
  });

  group('streak', () {
    test('starts at one', () {
      expect(nextStreak(null, '2026-11-10'), {
        'count': 1,
        'lastDay': '2026-11-10',
      });
    });

    test('goes up by one after yesterday', () {
      expect(nextStreak({'count': 4, 'lastDay': '2026-11-09'}, '2026-11-10'), {
        'count': 5,
        'lastDay': '2026-11-10',
      });
    });

    test('does not count the same day twice', () {
      expect(
        nextStreak({'count': 5, 'lastDay': '2026-11-10'}, '2026-11-10'),
        isNull,
      );
    });

    test('resets after a missed day', () {
      final old = {'count': 9, 'lastDay': '2026-11-08'};
      expect(nextStreak(old, '2026-11-10'), {
        'count': 1,
        'lastDay': '2026-11-10',
      });
      expect(shownStreak(old, '2026-11-10'), 0);
    });

    test('still shown the day after, before today is answered', () {
      final s = {'count': 3, 'lastDay': '2026-11-09'};
      expect(shownStreak(s, '2026-11-10'), 3);
      expect(shownStreak(s, '2026-11-09'), 3);
      expect(shownStreak(null, '2026-11-10'), 0);
    });
  });

  group('daily challenge', () {
    final bank = QuestionBank(['t0', 't1'], ['w0', 'w1', 'w2'], [
      ['p0', 'a', 'b'],
    ]);

    test('each day has one question of each type, stable for the day', () {
      final day = bank.forDay('2026-01-02');
      expect(day.map((q) => q.type), QuestionType.values);
      expect(day.map((q) => q.text), ['t1', 'w1', 'p0']);
      expect(day[2].options, ['a', 'b']);
      expect(bank.forDay('2026-01-03').map((q) => q.text), ['t0', 'w2', 'p0']);
    });

    test('answersOf reads slots and ignores malformed data', () {
      expect(answersOf(null), isEmpty);
      expect(answersOf({'answers': 3}), isEmpty);
      expect(
        answersOf({
          'answers': {
            'a': {'q0': 'hi', 'q2': ''},
            'b': 'junk',
          },
        }),
        {
          'a': ['hi', null, null],
        },
      );
    });

    test('the streak needs one real answer from each person', () {
      expect(hasAnswered([null, 'x', null]), isTrue);
      expect(hasAnswered([null, null, null]), isFalse);
      expect(hasAnswered(null), isFalse);
      const one = [null, 'x', null];
      expect(bothAnswered({'a': one}), isFalse);
      expect(
        bothAnswered({
          'a': one,
          'b': [null, null, null],
        }),
        isFalse,
      );
      expect(bothAnswered({'a': one, 'b': one}), isTrue);
    });

    test('shownAnswer names the chosen person', () {
      const who = DailyQuestion(QuestionType.who, 'w');
      const text = DailyQuestion(QuestionType.text, 't');
      expect(shownAnswer(who, 'u1', {'u1': 'Dash'}), 'Dash');
      expect(shownAnswer(who, 'friend', {}), 'Your friend');
      expect(shownAnswer(text, 'u1', {'u1': 'Dash'}), 'u1');
    });

    test('inbox holds only questions someone answered, newest day first', () {
      final items = inboxItems(
        {
          '2026-01-02': {
            'answers': {
              'me': {'q0': 'mine'},
              'her': {'q0': 'hers', 'q1': 'her'},
            },
          },
          '2026-01-03': {
            'answers': {
              'me': {'q2': 'a'},
            },
          },
          '2026-01-04': {'chat': {}},
          'junk': 1,
        },
        bank,
        'me',
      );
      expect(items.map((i) => '${i.day}/${i.slot}'), [
        '2026-01-03/2',
        '2026-01-02/0',
        '2026-01-02/1',
      ]);
      expect(items[1].mine, 'mine');
      expect(items[1].theirs, 'hers');
      expect(items[1].myTurn, isFalse);
      expect(items[2].myTurn, isTrue);
      expect(items[0].myTurn, isFalse);
      expect(inboxItems(null, bank, 'me'), isEmpty);
    });

    test('chat is read in send order and skips malformed messages', () {
      final day = {
        'chat': {
          'q1': {
            '-b': {'by': 'her', 'text': 'second'},
            '-a': {'by': 'me', 'text': 'first'},
            '-c': {'by': 'me'},
          },
        },
      };
      expect(chatOf(day, 1).map((m) => '${m.by}:${m.text}'), [
        'me:first',
        'her:second',
      ]);
      expect(chatOf(day, 0), isEmpty);
      expect(chatOf(null, 0), isEmpty);
    });
  });
}
