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
const _coral = Color(0xFFE8876C);

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

ThemeData _build(ColorScheme scheme, Playful playful) {
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Fredoka',
    extensions: [playful],
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
              ? scheme.onPrimaryContainer
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

/// A named colour set the user can pick in Settings.
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.text,
    required this.accent,
    required this.container,
    required this.highlight,
    required this.cards,
    required this.onCard,
    required this.paper,
  });

  final String id;
  final String name;
  final Color background;
  final Color text;

  /// Buttons and selected things.
  final Color accent;
  final Color container;

  /// "Your turn" pills and the second player's pieces.
  final Color highlight;
  final List<Color> cards;
  final Color onCard;
  final Color paper;
}

const defaultThemeId = 'tidepool';

const themes = [
  AppTheme(
    id: defaultThemeId,
    name: 'Tidepool',
    background: _veniceBlue,
    text: _merino,
    accent: _merino,
    container: _rockBlue,
    highlight: Color(0xFFF2A98C),
    cards: [_rockBlue, Color(0xFFA9CBDF), Color(0xFFC9DEEA)],
    onCard: _ink,
    paper: _merino,
  ),
  AppTheme(
    id: 'plum',
    name: 'Midnight Plum',
    background: Color(0xFF140919),
    text: Color(0xFFEFE8F5),
    accent: Color(0xFFC9B6E4),
    container: Color(0xFF4E325C),
    highlight: Color(0xFFE79AC6),
    cards: [Color(0xFF9A7BB0), Color(0xFFB39ACB), Color(0xFFCDBDE0)],
    onCard: Color(0xFF140919),
    paper: Color(0xFFEFE8F5),
  ),
  AppTheme(
    id: 'fog',
    name: 'Sea Fog',
    background: Color(0xFF0F1618),
    text: Color(0xFFD3DEDA),
    accent: Color(0xFFD3DEDA),
    container: Color(0xFF4C5866),
    highlight: Color(0xFFF0B28A),
    cards: [Color(0xFF839390), Color(0xFFABB9B6), Color(0xFFD3DEDA)],
    onCard: Color(0xFF0F1618),
    paper: Color(0xFFEEF3F1),
  ),
  AppTheme(
    id: 'storm',
    name: 'Storm Cellar',
    background: Color(0xFF0D0E0D),
    text: Color(0xFFE6E7EC),
    accent: Color(0xFFB9BBC8),
    container: Color(0xFF383B42),
    highlight: Color(0xFF9FB4E8),
    cards: [Color(0xFF8A8C9C), Color(0xFFA9ABB9), Color(0xFFC9CAD5)],
    onCard: Color(0xFF0D0E0D),
    paper: Color(0xFFF1F1F4),
  ),
  AppTheme(
    id: 'coven',
    name: 'Witching Hour',
    background: Color(0xFF240321),
    text: Color(0xFFFFFAFB),
    accent: Color(0xFFCFC3E4),
    container: Color(0xFF4F3841),
    highlight: Color(0xFFF2A7C3),
    cards: [Color(0xFFCFC3E4), Color(0xFFB9A6AF), Color(0xFFE4DCF0)],
    onCard: Color(0xFF240321),
    paper: Color(0xFFFFFAFB),
  ),
  AppTheme(
    id: 'jelly',
    name: 'Jellyfish',
    background: Color(0xFF1E201F),
    text: Color(0xFFE6F5F0),
    accent: Color(0xFF3EB9A8),
    container: Color(0xFF1D6C61),
    highlight: Color(0xFFF2C879),
    cards: [Color(0xFF3EB9A8), Color(0xFF5AA371), Color(0xFF8FD6C9)],
    onCard: Color(0xFF0E1F1B),
    paper: Color(0xFFEAF7F3),
  ),
];

/// The chosen theme's id. The app rebuilds when it changes.
final themeId = ValueNotifier<String>(defaultThemeId);

ColorScheme _schemeOf(AppTheme t) {
  Color mix(double amount) => Color.lerp(t.background, t.text, amount)!;
  return ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: t.accent,
    onPrimary: t.background,
    primaryContainer: t.container,
    onPrimaryContainer: t.text,
    secondary: Color.lerp(t.accent, t.text, 0.4),
    onSecondary: t.background,
    secondaryContainer: Color.lerp(t.background, t.accent, 0.3),
    onSecondaryContainer: t.text,
    tertiary: t.highlight,
    onTertiary: t.background,
    surface: t.background,
    onSurface: t.text,
    onSurfaceVariant: mix(0.72),
    surfaceBright: mix(0.16),
    surfaceContainerLowest: Color.lerp(
      t.background,
      const Color(0xFF000000),
      0.2,
    ),
    surfaceContainerLow: mix(0.04),
    surfaceContainer: mix(0.07),
    surfaceContainerHigh: mix(0.1),
    surfaceContainerHighest: mix(0.14),
    outline: mix(0.5),
    outlineVariant: mix(0.22),
  );
}

/// Tidepool follows the phone's light or dark setting; the others are dark.
ThemeData appTheme(String id, Brightness brightness) {
  final theme = themes.firstWhere(
    (t) => t.id == id,
    orElse: () => themes.first,
  );
  if (theme.id == defaultThemeId) {
    return _build(brightness == Brightness.dark ? _dark : _light, _playful);
  }
  return _build(
    _schemeOf(theme),
    Playful(cards: theme.cards, onCard: theme.onCard, paper: theme.paper),
  );
}
