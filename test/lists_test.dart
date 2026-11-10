import 'package:flutter_test/flutter_test.dart';
import 'package:duet/lists.dart';

void main() {
  final now = DateTime(2026, 11, 10, 23, 30);

  test('daysUntil counts calendar days, not 24-hour blocks', () {
    expect(daysUntil('2026-11-10', now), 0);
    expect(daysUntil('2026-11-11', now), 1);
    expect(daysUntil('2026-11-09', now), -1);
    expect(daysUntil('2027-11-10', now), 365);
    expect(daysUntil('not a date', now), isNull);
    expect(daysUntil(null, now), isNull);
  });

  test('countdownLabel wording', () {
    expect(countdownLabel(0), 'Today');
    expect(countdownLabel(1), 'Tomorrow');
    expect(countdownLabel(-1), 'Yesterday');
    expect(countdownLabel(12), '12 days left');
    expect(countdownLabel(-3), '3 days ago');
    expect(countdownLabel(null), 'No date');
  });

  test('entriesOf keeps well-formed items in key order', () {
    final entries = entriesOf({
      'b': {'text': 'second'},
      'a': {'text': 'first'},
      'c': 'junk',
    });
    expect(entries.map((e) => e.key), ['a', 'b']);
    expect(entriesOf(null), isEmpty);
  });
}
