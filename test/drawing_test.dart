import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:duet/drawing.dart';

void main() {
  test('points survive a round trip on the 1000-unit grid', () {
    const points = [Offset(0, 0), Offset(0.5, 0.25), Offset(1, 1)];
    expect(encodePoints(points), '0,0;500,250;1000,1000');
    expect(decodePoints(encodePoints(points)), points);
  });

  test('points outside the board are pulled back to its edge', () {
    expect(encodePoints(const [Offset(-0.2, 1.7)]), '0,1000');
  });

  test('decodePoints skips junk', () {
    expect(decodePoints(null), isEmpty);
    expect(decodePoints(''), isEmpty);
    expect(decodePoints('10,20;oops;30;40,x;50,60'), const [
      Offset(0.01, 0.02),
      Offset(0.05, 0.06),
    ]);
  });

  test('parseStrokes keeps send order and drops malformed strokes', () {
    final strokes = parseStrokes({
      '-b': {'c': 0xFFE07A5F, 'w': 14, 'p': '1,1;2,2', 'by': 'her'},
      '-a': {'c': 0xFF0D3A52, 'w': 6.0, 'p': '0,0', 'by': 'me'},
      '-c': {'c': 'red', 'w': 6, 'p': '0,0'},
      '-d': {'c': 0xFF000000, 'w': 6, 'p': ''},
      '-e': 'junk',
    });
    expect(strokes.map((s) => s.key), ['-a', '-b']);
    expect(strokes[0].by, 'me');
    expect(strokes[1].color, const Color(0xFFE07A5F));
    expect(strokes[1].width, 14);
    expect(parseStrokes(null), isEmpty);
  });

  test('a stroke written to the database reads back the same', () {
    const stroke = Stroke(
      color: Color(0xFF16587B),
      width: 28,
      points: [Offset(0.1, 0.2), Offset(0.3, 0.4)],
    );
    final back = parseStrokes({'-k': strokeToJson(stroke, 'me')}).single;
    expect(back.color, stroke.color);
    expect(back.width, stroke.width);
    expect(back.points, stroke.points);
    expect(back.by, 'me');
  });

  test('absurd widths from the database are limited', () {
    final stroke = parseStrokes({
      '-k': {'c': 0xFF000000, 'w': 9000, 'p': '0,0'},
    }).single;
    expect(stroke.width, 80);
  });
}
