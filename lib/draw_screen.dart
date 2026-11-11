import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'drawing.dart';
import 'notifications.dart';

// shortcut: old strokes are never merged, clear the board if drawing gets slow
const _maxStrokes = 600;

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key, required this.uid});

  final String uid;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  final _strokesRef = drawingRef().child('strokes');
  final _strokes = ValueNotifier<List<Stroke>>(const []);
  final _live = ValueNotifier<Stroke?>(null);
  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _publish;
  bool _loaded = false;
  bool _failed = false;
  bool _dirty = false;
  Color _color = penColors.first;
  double _width = penWidths[1];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    setState(() => _failed = false);
    _sub = _strokesRef.onValue.listen((event) {
      _strokes.value = parseStrokes(event.snapshot.value);
      if (!_loaded && mounted) setState(() => _loaded = true);
    }, onError: (_) => setState(() => _failed = true));
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_dirty) _publishNow();
    _publish?.cancel();
    _strokes.dispose();
    _live.dispose();
    super.dispose();
  }

  Offset _point(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0, 1),
    (local.dy / size.height).clamp(0, 1),
  );

  void _start(Offset p) {
    _publish?.cancel();
    _live.value = Stroke(color: _color, width: _width, points: [p]);
  }

  void _extend(Offset p) {
    final stroke = _live.value;
    if (stroke == null || (stroke.points.last - p).distance < 0.004) return;
    _live.value = Stroke(
      color: stroke.color,
      width: stroke.width,
      points: [...stroke.points, p],
    );
  }

  void _end() {
    final stroke = _live.value;
    if (stroke == null) return;
    if (_strokes.value.length >= _maxStrokes) {
      _live.value = null;
      _say('The board is full. Clear it to keep drawing.');
      return;
    }
    // Shown at once from the local write, so the live stroke can go.
    _strokesRef
        .push()
        .set(strokeToJson(stroke, widget.uid))
        .catchError((_) => _say('Could not save that line.'));
    _live.value = null;
    _changed();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// One picture and one push per pause in drawing, not per line.
  void _changed() {
    _dirty = true;
    _publish?.cancel();
    _publish = Timer(const Duration(milliseconds: 1500), _publishNow);
  }

  Future<void> _publishNow() async {
    _dirty = false;
    final strokes = _strokes.value;
    try {
      final preview = strokes.isEmpty
          ? null
          : encodePreview(await renderPng(strokes));
      await drawingRef().update({
        'preview': preview,
        'at': ServerValue.timestamp,
      });
      await showOnWidget(preview);
      unawaited(notifyFriend('drawing'));
    } catch (_) {}
  }

  void _undo() {
    final mine = _strokes.value.where((s) => s.by == widget.uid);
    if (mine.isEmpty) return;
    HapticFeedback.selectionClick();
    _strokesRef.child(mine.last.key).remove().catchError((_) {});
    _changed();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the board?'),
        content: const Text('This wipes the drawing for both of you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _strokesRef.remove().catchError((_) {});
    _changed();
  }

  Future<void> _addWidget() async {
    if (await HomeWidget.isRequestPinWidgetSupported() ?? false) {
      await HomeWidget.requestPinWidget(androidName: 'DrawingWidgetProvider');
    } else {
      _say('Long-press your home screen, tap Widgets and pick Duet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing board'),
        actions: [
          IconButton(
            tooltip: 'Undo my last line',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undo,
          ),
          IconButton(
            tooltip: 'Clear the board',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
          ),
          IconButton(
            tooltip: 'Add to home screen',
            icon: const Icon(Icons.add_to_home_screen_rounded),
            onPressed: _addWidget,
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                child: FilledButton(
                  onPressed: _listen,
                  child: const Text('Could not load. Try again'),
                ),
              )
            : !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: ColoredBox(
                              color: boardColor,
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final size = box.biggest;
                                  return Semantics(
                                    label: 'Shared drawing board',
                                    child: GestureDetector(
                                      onPanStart: (d) =>
                                          _start(_point(d.localPosition, size)),
                                      onPanUpdate: (d) => _extend(
                                        _point(d.localPosition, size),
                                      ),
                                      onPanEnd: (_) => _end(),
                                      onPanCancel: _end,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _BoardPainter(_strokes),
                                            ),
                                          ),
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _LivePainter(_live),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        for (final color in [...penColors, boardColor])
                          Expanded(
                            child: _Swatch(
                              color: color,
                              eraser: color == boardColor,
                              selected: color == _color,
                              ring: scheme.onSurface,
                              onTap: () => setState(() => _color = color),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton<double>(
                      showSelectedIcon: false,
                      segments: [
                        for (final (i, w) in penWidths.indexed)
                          ButtonSegment(
                            value: w,
                            label: Text(const ['Thin', 'Medium', 'Thick'][i]),
                          ),
                      ],
                      selected: {_width},
                      onSelectionChanged: (s) =>
                          setState(() => _width = s.first),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.eraser,
    required this.selected,
    required this.ring,
    required this.onTap,
  });

  final Color color;
  final bool eraser;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: eraser ? 'Eraser' : 'Pen colour',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.ease,
              width: selected ? 40 : 32,
              height: selected ? 40 : 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: selected ? 3 : 1),
              ),
              child: eraser
                  ? Icon(
                      Icons.auto_fix_normal,
                      size: 18,
                      color: penColors.first,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.strokes) : super(repaint: strokes);

  final ValueNotifier<List<Stroke>> strokes;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokes(canvas, size, strokes.value);

  @override
  bool shouldRepaint(_BoardPainter old) => old.strokes != strokes;
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.live) : super(repaint: live);

  final ValueNotifier<Stroke?> live;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = live.value;
    if (stroke != null) paintStrokes(canvas, size, [stroke]);
  }

  @override
  bool shouldRepaint(_LivePainter old) => old.live != live;
}
