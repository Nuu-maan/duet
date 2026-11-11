import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/painting.dart';
import 'package:home_widget/home_widget.dart';

import 'pair.dart';

/// The board is the same cream on both phones and on the widget, whatever
/// the theme, so a drawing looks the way its author saw it.
const boardColor = Color(0xFFF5EEDD);

const penColors = [
  Color(0xFF0D3A52),
  Color(0xFF16587B),
  Color(0xFF84B3CE),
  Color(0xFFE07A5F),
  Color(0xFFF2B84B),
  Color(0xFF6FAF7A),
];

const penWidths = [6.0, 14.0, 28.0];

const _grid = 1000;

class Stroke {
  const Stroke({
    required this.color,
    required this.width,
    required this.points,
    this.key = '',
    this.by = '',
  });

  final Color color;

  /// In board units: the board is [_grid] units wide.
  final double width;

  /// Each coordinate runs from 0 to 1 across the board.
  final List<Offset> points;
  final String key;
  final String by;
}

String encodePoints(List<Offset> points) => points
    .map(
      (p) =>
          '${(p.dx * _grid).round().clamp(0, _grid)},'
          '${(p.dy * _grid).round().clamp(0, _grid)}',
    )
    .join(';');

List<Offset> decodePoints(Object? text) {
  if (text is! String || text.isEmpty) return const [];
  final points = <Offset>[];
  for (final pair in text.split(';')) {
    final xy = pair.split(',');
    final x = xy.length == 2 ? int.tryParse(xy[0]) : null;
    final y = xy.length == 2 ? int.tryParse(xy[1]) : null;
    if (x != null && y != null) points.add(Offset(x / _grid, y / _grid));
  }
  return points;
}

/// Oldest first, so later strokes paint over earlier ones.
List<Stroke> parseStrokes(Object? value) {
  if (value is! Map) return const [];
  final keys = value.keys.whereType<String>().toList()..sort();
  final strokes = <Stroke>[];
  for (final key in keys) {
    final data = value[key];
    if (data is! Map) continue;
    final points = decodePoints(data['p']);
    final color = data['c'];
    final width = data['w'];
    if (points.isEmpty || color is! int || width is! num) continue;
    strokes.add(
      Stroke(
        key: key,
        by: '${data['by'] ?? ''}',
        color: Color(color),
        width: width.toDouble().clamp(1, 80),
        points: points,
      ),
    );
  }
  return strokes;
}

Map<String, Object> strokeToJson(Stroke stroke, String uid) => {
  'c': stroke.color.toARGB32(),
  'w': stroke.width,
  'p': encodePoints(stroke.points),
  'by': uid,
};

void paintStrokes(Canvas canvas, Size size, Iterable<Stroke> strokes) {
  final scale = size.width / _grid;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final stroke in strokes) {
    paint
      ..color = stroke.color
      ..strokeWidth = stroke.width * scale;
    final first = stroke.points.first;
    if (stroke.points.length == 1) {
      canvas.drawPoints(ui.PointMode.points, [
        Offset(first.dx * size.width, first.dy * size.height),
      ], paint);
      continue;
    }
    final path = Path()..moveTo(first.dx * size.width, first.dy * size.height);
    for (final p in stroke.points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }
}

Future<Uint8List> renderPng(List<Stroke> strokes, {int size = 512}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final box = Size(size.toDouble(), size.toDouble());
  canvas.drawRect(Offset.zero & box, Paint()..color = boardColor);
  paintStrokes(canvas, box, strokes);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

DatabaseReference drawingRef() =>
    FirebaseDatabase.instance.ref('$dbRoot/drawing');

Future<void> showOnWidget(String? pngBase64) async {
  await HomeWidget.saveWidgetData<String>('drawing', pngBase64);
  await HomeWidget.updateWidget(androidName: 'DrawingWidgetProvider');
}

/// Fetches the latest picture and puts it on the home-screen widget.
/// Safe to call from the background isolate that handles a push.
Future<void> syncWidgetFromDatabase() async {
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.authStateChanges().first;
  }
  if (FirebaseAuth.instance.currentUser == null) return;
  final preview = (await drawingRef().child('preview').get()).value;
  await showOnWidget(preview is String ? preview : null);
}

String encodePreview(Uint8List png) => base64Encode(png);
