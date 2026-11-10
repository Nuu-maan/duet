import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'appear.dart';
import 'art.dart';
import 'daily.dart';
import 'play_card.dart';
import 'theme.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  final _events = streakRef().onValue;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String _message(Object? streak, String today, int run, bool anyDays) {
    final answeredToday = streak is Map && streak['lastDay'] == today;
    if (run == 0) {
      return anyDays
          ? 'The fire went out. Both answer today to start again.'
          : 'Both answer a question two days in a row to light the fire.';
    }
    if (run == 1) {
      return answeredToday
          ? 'Day one done! Both answer again tomorrow and the streak begins.'
          : 'Both answer today and the streak begins.';
    }
    return answeredToday
        ? 'You both answered today. See you tomorrow!'
        : 'Both answer today to keep it alive.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = theme.extension<Playful>()!.onCard;
    final now = DateTime.now();
    final today = dayKey(now);
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: const Text('Streak')),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const MascotMessage(
                mascot: 'mascot_shocked',
                title: 'Could not load the streak',
                body: 'Check your connection.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final streak = snapshot.data!.snapshot.value;
            final shown = displayStreak(streak, today);
            final days = streakDays(streak);
            final run = currentRun(streak, today);
            final still = MediaQuery.disableAnimationsOf(context);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Appear(
                  child: PlayCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Art('fire', size: 72),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: still ? shown : 0, end: shown),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            '$value',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: onCard,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'day streak',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: onCard,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _message(
                            streak,
                            today,
                            shownStreak(streak, today),
                            days.isNotEmpty,
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: onCard,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Best streak',
                        value: bestStreak(streak),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Stat(label: 'Days together', value: days.length),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthNames[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: isThisMonth
                          ? null
                          : () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                        Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label:
                      '${days.where((d) => d.startsWith(dayKey(_month).substring(0, 7))).length} '
                      'streak days in ${_monthNames[_month.month - 1]}',
                  child: AspectRatio(
                    aspectRatio: 7 / 6,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _MonthPainter(
                          month: _month,
                          days: days,
                          run: run,
                          today: today,
                          runColor: scheme.tertiary,
                          onRun: scheme.onTertiary,
                          earlierColor: scheme.primaryContainer,
                          onEarlier: scheme.onPrimaryContainer,
                          todayColor: scheme.primary,
                          text: theme.textTheme.bodyLarge!,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Legend(color: scheme.tertiary, label: 'Current streak'),
                    _Legend(
                      color: scheme.primaryContainer,
                      label: 'Earlier days',
                    ),
                    _Legend(color: scheme.primary, label: 'Today', ring: true),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$value', style: theme.textTheme.headlineMedium),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.ring = false});

  final Color color;
  final String label;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ring ? null : color,
            border: ring ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MonthPainter extends CustomPainter {
  _MonthPainter({
    required this.month,
    required this.days,
    required this.run,
    required this.today,
    required this.runColor,
    required this.onRun,
    required this.earlierColor,
    required this.onEarlier,
    required this.todayColor,
    required this.text,
  });

  final DateTime month;
  final Set<String> days;
  final Set<String> run;
  final String today;
  final Color runColor;
  final Color onRun;
  final Color earlierColor;
  final Color onEarlier;
  final Color todayColor;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 7, h = size.height / 6;
    final radius = (w < h ? w : h) * 0.4;
    final offset = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    String key(int day) => dayKey(DateTime(month.year, month.month, day));
    Offset centre(int day) {
      final i = offset + day - 1;
      return Offset((i % 7 + 0.5) * w, (i ~/ 7 + 0.5) * h);
    }

    Color fill(String k) => run.contains(k) ? runColor : earlierColor;

    // Bands first, so neighbouring streak days read as one unbroken run.
    for (var day = 1; day < count; day++) {
      final a = key(day), b = key(day + 1);
      if (!days.contains(a) || !days.contains(b)) continue;
      if ((offset + day - 1) % 7 == 6) continue;
      canvas.drawRect(
        Rect.fromLTRB(
          centre(day).dx,
          centre(day).dy - radius,
          centre(day + 1).dx,
          centre(day).dy + radius,
        ),
        Paint()
          ..color = run.contains(a) && run.contains(b)
              ? runColor
              : earlierColor,
      );
    }
    for (var day = 1; day <= count; day++) {
      final k = key(day);
      final marked = days.contains(k);
      if (marked) {
        canvas.drawCircle(centre(day), radius, Paint()..color = fill(k));
      }
      if (k == today) {
        canvas.drawCircle(
          centre(day),
          radius + 3,
          Paint()
            ..color = todayColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      final label = TextPainter(
        text: TextSpan(
          text: '$day',
          style: marked
              ? text.copyWith(
                  color: run.contains(k) ? onRun : onEarlier,
                  fontWeight: FontWeight.w700,
                )
              : text,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        centre(day) - Offset(label.width / 2, label.height / 2),
      );
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(_MonthPainter old) =>
      old.month != month ||
      old.today != today ||
      old.runColor != runColor ||
      old.earlierColor != earlierColor ||
      old.todayColor != todayColor ||
      old.text != text ||
      !setEquals(old.days, days) ||
      !setEquals(old.run, run);
}
