import 'package:flutter_test/flutter_test.dart';
import 'package:duet/pair.dart';

void main() {
  group('presenceLabel', () {
    final now = DateTime(2026, 11, 10, 9, 30);

    String label(DateTime? lastSeen, {bool online = false}) =>
        presenceLabel(online: online, lastSeen: lastSeen, now: now);

    test('online wins over last seen', () {
      expect(label(DateTime(2026, 11, 1), online: true), 'Online');
    });

    test('never seen', () {
      expect(label(null), 'Offline');
    });

    test('earlier today', () {
      expect(label(DateTime(2026, 11, 10, 8, 5)), 'Last seen today at 08:05');
    });

    test('server clock ahead of the phone still reads as today', () {
      expect(label(DateTime(2026, 11, 10, 9, 31)), 'Last seen today at 09:31');
    });

    test('late last night is yesterday, not today', () {
      expect(
        label(DateTime(2026, 11, 9, 23, 59)),
        'Last seen yesterday at 23:59',
      );
    });

    test('older shows the date', () {
      expect(label(DateTime(2026, 11, 8, 14, 0)), 'Last seen 8 Nov at 14:00');
    });
  });

  test('daysToBirthday counts to the next one and wraps the year', () {
    final now = DateTime(2026, 11, 10, 22);
    expect(daysToBirthday('2001-11-10', now), 0);
    expect(daysToBirthday('2001-11-11', now), 1);
    expect(daysToBirthday('2001-11-09', now), 364);
    expect(daysToBirthday('2001-01-01', now), 52);
    expect(daysToBirthday(null, now), isNull);
    expect(daysToBirthday('soon', now), isNull);
  });

  group('parseMembers', () {
    test('puts me first and reads fields', () {
      final members = parseMembers({
        'aaa': {'name': 'Dash', 'online': true, 'lastSeen': 1000},
        'zzz': {
          'name': 'Dot',
          'photoUrl': 'https://x/y.png',
          'birthday': '2001-05-04',
        },
      }, myUid: 'zzz');

      expect(members.map((m) => m.uid), ['zzz', 'aaa']);
      expect(members[0].photoUrl, 'https://x/y.png');
      expect(members[0].online, false);
      expect(members[0].birthday, '2001-05-04');
      expect(members[1].birthday, isNull);
      expect(members[0].lastSeen, isNull);
      expect(members[1].online, true);
      expect(members[1].lastSeen, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('decodes an uploaded photo once and reuses the bytes', () {
      Map<String, Object> data(String photo) => {
        'me': {'name': 'Dot', 'photo': photo},
      };
      final first = parseMembers(data('AQID'), myUid: 'me').single.photo;
      expect(first, [1, 2, 3]);
      expect(
        identical(parseMembers(data('AQID'), myUid: 'me').single.photo, first),
        isTrue,
      );
      expect(parseMembers(data('BAUG'), myUid: 'me').single.photo, [4, 5, 6]);
      expect(
        parseMembers(data('not base64!'), myUid: 'me').single.photo,
        isNull,
      );
    });

    test('tolerates missing and malformed data', () {
      expect(parseMembers(null, myUid: 'me'), isEmpty);
      final members = parseMembers({
        'me': {'name': '', 'photoUrl': ''},
        'junk': 'not a map',
      }, myUid: 'me');
      expect(members.single.name, 'Unknown');
      expect(members.single.photoUrl, isNull);
    });
  });
}
