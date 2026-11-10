import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';
import 'confetti.dart';
import 'daily.dart';
import 'pair.dart';
import 'theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.user});

  final User user;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _steps = 4;

  final _pages = PageController();
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final _name = TextEditingController(
    text: (widget.user.displayName ?? '').split(' ').first,
  );
  DateTime _birthday = DateTime(2000);
  int _step = 0;
  bool _saving = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _loop.dispose();
    _confetti.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int step) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (_still) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      if (step == _steps - 1) {
        HapticFeedback.heavyImpact();
        _confetti.forward(from: 0);
      }
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await membersRef().child(widget.user.uid).update({
        'name': _name.text.trim(),
        'birthday': dayKey(_birthday),
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }

  Widget _mascot(String name, double size) {
    final art = Art(name, size: size);
    if (_still) return art;
    return AnimatedBuilder(
      animation: _loop,
      child: art,
      builder: (context, child) {
        final t = _loop.value * 2 * pi;
        return Transform.translate(
          offset: Offset(0, sin(t * 4) * 8),
          child: Transform.rotate(angle: sin(t * 3) * 0.06, child: child),
        );
      },
    );
  }

  Widget _page(int index, List<Widget> children) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed)
              _Pop(
                key: ValueKey((index, i, _step == index)),
                delay: i * 90,
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    final scheme = theme.colorScheme;
    final name = _name.text.trim();
    final headline = theme.textTheme.headlineMedium;
    final body = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const gap = SizedBox(height: 16);

    return Scaffold(
      body: Stack(
        children: [
          if (!_still)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BubblesPainter(_loop, playful.cards),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: _saving ? null : () => _go(_step - 1),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Semantics(
                          label: 'Step ${_step + 1} of $_steps',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _steps; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: i == _step ? 28 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i <= _step
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _page(0, [
                        _mascot('mascot_hi', 200),
                        gap,
                        Text(
                          'Hi! We are Dot and Dash',
                          style: headline,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This little app is just for the two of you. '
                          'Two quick questions and we are in.',
                          style: body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () => _go(1),
                          child: const Text("Let's go"),
                        ),
                      ]),
                      _page(1, [
                        _mascot('mascot_hi', 128),
                        gap,
                        Text(
                          'What should we call you?',
                          style: headline,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _name,
                          maxLength: 20,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          style: theme.textTheme.headlineSmall,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (name.isNotEmpty) _go(2);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: name.isEmpty ? null : () => _go(2),
                          child: const Text('Next'),
                        ),
                      ]),
                      _page(2, [
                        _mascot('mascot_excited', 128),
                        gap,
                        Text(
                          'When is your birthday, $name?',
                          style: headline,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'So your friend never forgets it.',
                          style: body,
                          textAlign: TextAlign.center,
                        ),
                        gap,
                        SizedBox(
                          height: 180,
                          child: CupertinoTheme(
                            data: CupertinoThemeData(
                              brightness: theme.brightness,
                              textTheme: CupertinoTextThemeData(
                                dateTimePickerTextStyle:
                                    theme.textTheme.titleLarge,
                              ),
                            ),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: _birthday,
                              minimumYear: 1940,
                              maximumDate: DateTime.now(),
                              onDateTimeChanged: (d) => _birthday = d,
                            ),
                          ),
                        ),
                        gap,
                        FilledButton(
                          onPressed: () => _go(3),
                          child: const Text('Next'),
                        ),
                      ]),
                      _page(3, [
                        _mascot('mascot_excited', 200),
                        gap,
                        Text(
                          'You are all set, $name!',
                          style: headline,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily questions, games and lists are waiting.',
                          style: body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: _saving ? null : _finish,
                          child: Text(_saving ? 'Saving…' : 'Start'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_still)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ConfettiPainter(_confetti, [
                      ...playful.cards,
                      playful.paper,
                      scheme.tertiary,
                      scheme.primary,
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    const length = 450;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: delay + length),
      curve: Interval(delay / (delay + length), 1),
      child: child,
      builder: (context, t, child) {
        if (still) {
          return FadeTransition(
            opacity: AlwaysStoppedAnimation(t),
            child: child,
          );
        }
        final bounce = Curves.easeOutBack.transform(t);
        return FadeTransition(
          opacity: AlwaysStoppedAnimation(t),
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - bounce)),
            child: Transform.scale(scale: 0.7 + 0.3 * bounce, child: child),
          ),
        );
      },
    );
  }
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.loop, this.colors) : super(repaint: loop);

  final Animation<double> loop;
  final List<Color> colors;

  static final _bubbles = () {
    final rng = Random(7);
    return [
      for (var i = 0; i < 14; i++)
        (
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          radius: 12 + rng.nextDouble() * 36,
          laps: 1 + rng.nextInt(3),
          sway: rng.nextDouble() * 2 * pi,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final (i, b) in _bubbles.indexed) {
      final y = (b.y - loop.value * b.laps) % 1;
      final x = b.x + sin(loop.value * 2 * pi * b.laps + b.sway) * 0.04;
      paint.color = colors[i % colors.length].withValues(alpha: 0.28);
      canvas.drawCircle(
        Offset(x * size.width, y * (size.height + 120) - 60),
        b.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.colors != colors;
}
