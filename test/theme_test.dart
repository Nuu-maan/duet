import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duet/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('theme ids are unique and the default exists', () {
    expect(themes.map((t) => t.id).toSet(), hasLength(themes.length));
    expect(themes.any((t) => t.id == defaultThemeId), isTrue);
  });

  test('an unknown id falls back to the default theme', () {
    expect(
      appTheme('nope', Brightness.dark).colorScheme.surface,
      appTheme(defaultThemeId, Brightness.dark).colorScheme.surface,
    );
  });

  for (final brightness in Brightness.values) {
    for (final option in themes) {
      test('${option.name} (${brightness.name}) keeps text readable', () {
        final theme = appTheme(option.id, brightness);
        final scheme = theme.colorScheme;
        final playful = theme.extension<Playful>()!;
        final pairs = {
          'text on background': (scheme.onSurface, scheme.surface),
          'muted text on background': (scheme.onSurfaceVariant, scheme.surface),
          'text on a plain card': (
            scheme.onSurface,
            scheme.surfaceContainerHigh,
          ),
          'button label': (scheme.onPrimary, scheme.primary),
          'selected tab icon': (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
          'text on paper': (playful.onCard, playful.paper),
          'your-turn pill': (playful.onCard, scheme.tertiary),
          for (final (i, card) in playful.cards.indexed)
            'text on colour card $i': (playful.onCard, card),
        };
        for (final entry in pairs.entries) {
          expect(
            contrast(entry.value.$1, entry.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: entry.key,
          );
        }
      });
    }
  }
}
