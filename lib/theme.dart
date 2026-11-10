import 'package:flutter/material.dart';

class Playful extends ThemeExtension<Playful> {
  const Playful({
    required this.cards,
    required this.onCard,
    required this.paper,
  });

  final List<Color> cards;
  final Color onCard;
  final Color paper;

  Color card(int index) => cards[index % cards.length];

  @override
  Playful copyWith() => this;

  @override
  Playful lerp(Playful? other, double t) => t < 0.5 ? this : other ?? this;
}

const _merino = Color(0xFFF5EEDD);
const _rockBlue = Color(0xFF84B3CE);
const _veniceBlue = Color(0xFF16587B);
const _ink = Color(0xFF0D3A52);
const _coral = Color(0xFFE07A5F);

const _playful = Playful(
  onCard: _ink,
  paper: _merino,
  cards: [_rockBlue, Color(0xFFA9CBDF), Color(0xFFC9DEEA)],
);

const _light = ColorScheme(
  brightness: Brightness.light,
  primary: _veniceBlue,
  onPrimary: _merino,
  primaryContainer: _rockBlue,
  onPrimaryContainer: _ink,
  secondary: Color(0xFF3D6A85),
  onSecondary: _merino,
  secondaryContainer: Color(0xFFC9DEEA),
  onSecondaryContainer: _ink,
  tertiary: _coral,
  onTertiary: _ink,
  error: Color(0xFFB3261E),
  onError: _merino,
  surface: _merino,
  onSurface: _ink,
  onSurfaceVariant: Color(0xFF3D6A85),
  surfaceBright: Color(0xFFFFFBF0),
  surfaceContainerLowest: Color(0xFFFFFBF0),
  surfaceContainerLow: Color(0xFFFAF5E8),
  surfaceContainer: Color(0xFFF0E8D3),
  surfaceContainerHigh: Color(0xFFEBE2CB),
  surfaceContainerHighest: Color(0xFFE4DAC0),
  outline: Color(0xFF6F99B1),
  outlineVariant: Color(0xFFC6D3D3),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: _merino,
  onPrimary: _veniceBlue,
  primaryContainer: _rockBlue,
  onPrimaryContainer: _ink,
  secondary: Color(0xFFC9DEEA),
  onSecondary: _ink,
  secondaryContainer: Color(0xFF2A7399),
  onSecondaryContainer: _merino,
  tertiary: Color(0xFFF2A98C),
  onTertiary: _ink,
  error: Color(0xFFFFB4AB),
  onError: _ink,
  surface: _veniceBlue,
  onSurface: _merino,
  onSurfaceVariant: Color(0xFFC9DEEA),
  surfaceBright: Color(0xFF2A7399),
  surfaceContainerLowest: Color(0xFF104661),
  surfaceContainerLow: Color(0xFF124C6B),
  surfaceContainer: Color(0xFF1B6088),
  surfaceContainerHigh: Color(0xFF20698F),
  surfaceContainerHighest: Color(0xFF2A7399),
  outline: _rockBlue,
  outlineVariant: Color(0xFF3A7A9C),
);

ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.dark ? _dark : _light;
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Fredoka',
    extensions: const [_playful],
  );
  TextStyle? bold(TextStyle? style) =>
      style?.copyWith(fontWeight: FontWeight.w700);
  final text = base.textTheme;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    textTheme: text.copyWith(
      headlineLarge: bold(text.headlineLarge),
      headlineMedium: bold(text.headlineMedium),
      headlineSmall: bold(text.headlineSmall),
      titleLarge: bold(text.titleLarge),
      titleMedium: bold(text.titleMedium),
      labelLarge: bold(text.labelLarge),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      titleTextStyle: bold(text.headlineSmall),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: shape,
        textStyle: bold(text.titleMedium),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(bold(text.labelMedium)),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? _ink
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
