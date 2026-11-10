import 'package:firebase_database/firebase_database.dart';

DatabaseReference bucketRef() =>
    FirebaseDatabase.instance.ref('pair/lists/bucket');

DatabaseReference countdownsRef() =>
    FirebaseDatabase.instance.ref('pair/countdowns');

List<MapEntry<String, Map<Object?, Object?>>> entriesOf(Object? value) {
  if (value is! Map) return const [];
  return [
    for (final e in value.entries)
      if (e.key is String && e.value is Map)
        MapEntry(e.key as String, e.value as Map<Object?, Object?>),
  ]..sort((a, b) => a.key.compareTo(b.key));
}

int? daysUntil(Object? date, DateTime now) {
  final target = date is String ? DateTime.tryParse(date) : null;
  if (target == null) return null;
  return DateTime.utc(
    target.year,
    target.month,
    target.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

String countdownLabel(int? days) {
  if (days == null) return 'No date';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  return days > 0 ? '$days days left' : '${-days} days ago';
}
