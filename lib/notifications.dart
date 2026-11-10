import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'pair.dart';

/// What the notification server needs to know about one phone and its owner.
DatabaseReference deviceRef(String uid) =>
    FirebaseDatabase.instance.ref('$dbRoot/devices/$uid');

/// Reminder lines written for [uid] by the other person.
DatabaseReference nudgesRef(String uid) =>
    FirebaseDatabase.instance.ref('$dbRoot/nudges/$uid');

// shortcut: the token is refreshed on app start only, listen to
// onTokenRefresh if pushes go missing for people who rarely open the app
Future<void> registerDevice(
  String uid, {
  required String name,
  String? birthday,
}) async {
  await deviceRef(uid).update({
    'name': name,
    'birthday': birthday,
    'tz': DateTime.now().timeZoneOffset.inMinutes,
  });
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  // The replacement API hands out an installation ID; the server sends to tokens.
  // ignore: deprecated_member_use
  final token = await messaging.getToken();
  if (token != null) await deviceRef(uid).update({'token': token});
}

String? _notifyUrl;

/// Asks the server to tell the other person. Never throws: a missed
/// notification must not break the action that caused it.
Future<void> notifyFriend(
  String kind, [
  Map<String, Object?> details = const {},
]) async {
  try {
    _notifyUrl ??=
        (await FirebaseDatabase.instance.ref('$dbRoot/config/notifyUrl').get())
                .value
            as String?;
    final url = _notifyUrl;
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (url == null || idToken == null) return;
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$url/event'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({...details, 'kind': kind, 'idToken': idToken}));
      await (await request.close()).drain<void>();
    } finally {
      client.close();
    }
  } catch (_) {}
}
