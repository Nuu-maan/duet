---
description: UI and motion rules for Duet. Apply when writing or changing any widget, screen, animation or theme.
paths:
  - "**/lib/**/*.dart"
---

# UI rules

The app must feel quick on a low-end phone. Motion explains a change; it is never decoration.

## Should it animate at all?
- Something the user does many times a session (placing a game piece, switching tabs): 150 ms or less, or nothing.
- Something that appears or leaves (sheet, dialog, answer reveal): yes, short.
- A rare, earned moment (streak goes up, game won): one richer animation is fine.
- If you cannot say what the motion explains, remove it.

## Durations
| What | Duration |
|---|---|
| Press feedback | 100–150 ms |
| Small things: chips, toasts, piece placement | 150–200 ms |
| Sheets, dialogs, page transitions | 200–300 ms |
| Celebration (streak, win) | up to 600 ms, once |

Leaving is faster than entering: use about two thirds of the enter duration.

## Curves
- Entering or leaving: `Curves.easeOutCubic`
- Moving between two on-screen positions: `Curves.easeInOutCubic`
- Colour or opacity only: `Curves.ease`
- Never `Curves.easeIn` for UI, and never `Curves.bounceOut` or `Curves.elasticOut` outside a celebration.
- Dragging and flinging: use a `SpringSimulation` driven by the release velocity, not a fixed-duration tween,
  so an interrupted gesture continues smoothly.

## Patterns
- Press: scale to 0.97 with `AnimatedScale`, plus `HapticFeedback.selectionClick()` on game moves.
- Appear: fade in while scaling from 0.95. Never scale from 0.
- Lists that load together: stagger items by 30–50 ms, at most 6 items; the rest appear at once.
- Reduced motion: if `MediaQuery.disableAnimationsOf(context)` is true, keep fades and drop movement and scale.

## Performance
- Prefer implicit widgets (`AnimatedScale`, `AnimatedOpacity`, `AnimatedSlide`, `AnimatedSwitcher`,
  `TweenAnimationBuilder`). Use an `AnimationController` only when a gesture drives the animation.
- Pass the static subtree as `child` to `AnimatedBuilder` so it is not rebuilt every frame.
- Wrap each game board in a `RepaintBoundary`; give its `CustomPainter` a `repaint` listenable and a real
  `shouldRepaint`. Never call `setState` on a whole screen for a per-frame change.
- Animate transform and opacity. Do not animate size, padding or anything that forces layout of a long list.
- No `BackdropFilter` blur, no `saveLayer`, no `Opacity` wrapped around a large subtree
  (use `AnimatedOpacity` or a colour with alpha).
- `const` constructors wherever possible. Images are WebP, sized close to their display size.
- No Lottie, Rive or video. Celebrations are drawn with `CustomPainter`.

## Look
- All colours, text styles and radii come from `Theme.of(context)`. One `ThemeData` built with
  `ColorScheme.fromSeed`, light and dark. No hard-coded colours or font sizes in widgets.
- Spacing on a 4 px grid: 4, 8, 12, 16, 24, 32.
- Touch targets at least 48 × 48. Body text contrast at least 4.5:1.
- Every icon-only button has a `tooltip`. Text must survive the system font scale at 1.3 without overflow.
- Every screen handles four states: loading, empty, error, content. Wrap content in `SafeArea`.

## Checking
Judge smoothness only with `flutter run --release` (or `--profile` with the performance overlay) on a real phone.
Debug builds are several times slower and prove nothing.
