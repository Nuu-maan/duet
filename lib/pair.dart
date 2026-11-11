import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Member {
  const Member({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.online,
    required this.lastSeen,
    this.birthday,
    this.photo,
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final bool online;
  final DateTime? lastSeen;
  final String? birthday;
  final Uint8List? photo;
}

final _photoCache = <String, (String, Uint8List)>{};

// Returns the same bytes object for an unchanged photo so the image cache
// keeps hitting and avatars do not flicker on every presence update.
Uint8List? _decodePhoto(String uid, Object? encoded) {
  if (encoded is! String || encoded.isEmpty) return null;
  final cached = _photoCache[uid];
  if (cached != null && cached.$1 == encoded) return cached.$2;
  try {
    final bytes = base64Decode(encoded);
    _photoCache[uid] = (encoded, bytes);
    return bytes;
  } on FormatException {
    return null;
  }
}

List<Member> parseMembers(Object? value, {required String myUid}) {
  if (value is! Map) return const [];
  final members = <Member>[];
  value.forEach((uid, data) {
    if (uid is! String || data is! Map) return;
    final name = data['name'];
    final photoUrl = data['photoUrl'];
    final lastSeen = data['lastSeen'];
    final birthday = data['birthday'];
    members.add(
      Member(
        uid: uid,
        name: name is String && name.isNotEmpty ? name : 'Unknown',
        photoUrl: photoUrl is String && photoUrl.isNotEmpty ? photoUrl : null,
        online: data['online'] == true,
        lastSeen: lastSeen is int
            ? DateTime.fromMillisecondsSinceEpoch(lastSeen)
            : null,
        birthday: birthday is String ? birthday : null,
        photo: _decodePhoto(uid, data['photo']),
      ),
    );
  });
  members.sort((a, b) {
    if (a.uid == myUid) return -1;
    if (b.uid == myUid) return 1;
    return a.uid.compareTo(b.uid);
  });
  return members;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String presenceLabel({
  required bool online,
  required DateTime? lastSeen,
  required DateTime now,
}) {
  if (online) return 'Online';
  if (lastSeen == null) return 'Offline';
  final time =
      '${lastSeen.hour.toString().padLeft(2, '0')}:'
      '${lastSeen.minute.toString().padLeft(2, '0')}';
  final daysAgo = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(lastSeen.year, lastSeen.month, lastSeen.day))
      .inDays;
  if (daysAgo <= 0) return 'Last seen today at $time';
  if (daysAgo == 1) return 'Last seen yesterday at $time';
  return 'Last seen ${lastSeen.day} ${_months[lastSeen.month - 1]} at $time';
}

int? daysToBirthday(String? birthday, DateTime now) {
  final born = birthday == null ? null : DateTime.tryParse(birthday);
  if (born == null) return null;
  final today = DateTime.utc(now.year, now.month, now.day);
  var next = DateTime.utc(now.year, born.month, born.day);
  if (next.isBefore(today)) {
    next = DateTime.utc(now.year + 1, born.month, born.day);
  }
  return next.difference(today).inDays;
}

/// Everything lives under this node. Override it with
/// `--dart-define=DUET_ROOT=demo` to run against a separate copy of the data.
const dbRoot = String.fromEnvironment('DUET_ROOT', defaultValue: 'pair');

DatabaseReference membersRef() =>
    FirebaseDatabase.instance.ref('$dbRoot/members');

class Presence {
  Presence(this._user) {
    final db = FirebaseDatabase.instance;
    _connected = db.ref('.info/connected').onValue.listen((event) {
      if (event.snapshot.value == true) _announce();
    });
    _lifecycle = AppLifecycleListener(
      onPause: db.goOffline,
      onResume: db.goOnline,
    );
  }

  final User _user;
  late final StreamSubscription<DatabaseEvent> _connected;
  late final AppLifecycleListener _lifecycle;
  bool _stopped = false;

  DatabaseReference get _me => membersRef().child(_user.uid);

  static const _offline = {'online': false, 'lastSeen': ServerValue.timestamp};

  Future<void> _announce() async {
    try {
      await _me.onDisconnect().update(_offline);
      await _me.update({
        'photoUrl':
            _user.photoURL ?? _user.providerData.firstOrNull?.photoURL ?? '',
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });
    } on FirebaseException catch (_) {}
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _connected.cancel();
    _lifecycle.dispose();
    try {
      await _me.onDisconnect().cancel();
      await _me.update(_offline);
    } on FirebaseException catch (_) {}
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.radius = 24,
    this.showOnline = true,
  });

  final Member member;
  final double radius;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = member.photo;
    final photoUrl = member.photoUrl;
    final avatar = CircleAvatar(
      radius: radius,
      foregroundImage: photo != null
          ? MemoryImage(photo)
          : photoUrl != null
          ? NetworkImage(photoUrl) as ImageProvider
          : null,
      child: Text(member.name.characters.first.toUpperCase()),
    );
    if (!showOnline) return avatar;
    return Semantics(
      label: '${member.name}, ${member.online ? 'online' : 'offline'}',
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: member.online ? scheme.primary : scheme.outline,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
