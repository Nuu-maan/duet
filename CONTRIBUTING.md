# Contributing to Duet

Thanks for helping. Duet is deliberately small, so the bar for adding things is "two people will use this, and it
stays free and light".

## Ground rules

- **Free only.** Nothing that needs a paid plan or a credit card. Firebase Spark plan only.
- **Light.** No Lottie, Rive, video or bundled images. Draw with `CustomPainter`. No state-management library;
  use `StreamBuilder` and `ValueNotifier`. Do not add a dependency for a few lines of code.
- **Two people.** No public sign-up, pairing codes, paywalls, ads or analytics.
- **Original material only.** Do not add text, art, fonts or code taken from other apps. Anything you add must be
  your own work or under a licence compatible with MIT (say which in the pull request).

## Workflow

1. Open an issue first for anything larger than a small fix, so we can agree on the approach.
2. Fork, create a branch, and keep commits small and focused.
3. Before opening a pull request:

   ```sh
   dart format lib test
   flutter analyze
   flutter test
   (cd worker && node --test)   # only if you touched worker/
   ```

4. Try UI changes on a real phone with `flutter run --release`. Debug builds are several times slower and say
   nothing about smoothness.
5. Open the pull request against `main` and fill in the template. CI runs format, analyze and tests.

## Code style

- Follow `analysis_options.yaml` and `dart format`.
- Prefer clear names and small functions over comments. Comment only when leaving it out would let someone
  silently break something.
- All colours, text styles and radii come from `Theme.of(context)`; see `lib/theme.dart`.
- Motion and layout rules are in `.claude/rules/ui.md`. They apply to everyone, not only to AI agents.

## Tests

Any non-trivial logic needs a unit test. Every game must test win detection and illegal moves; see
`test/games/`. Keep rules pure (no Flutter or Firebase imports needed to run them) so they are easy to test.

## Adding a game

1. Create `lib/games/your_game.dart` with a class that extends `Game` (`lib/games/game.dart`).
   - `start` returns the initial state as a JSON-friendly map with a `turn` field.
   - `move` returns the next state, or `null` if the move is illegal. It must not mutate its input.
   - `board` returns the widget; wrap painters in a `RepaintBoundary` or use `GridBoard`.
2. Add it to the `games` list in `lib/games/games_screen.dart`.
3. Add tests under `test/games/`.

The shared room (`lib/games/room.dart`) handles seats, turns, rejoining and "play again", so a game is only its
rules and its board.

## Adding questions

Edit `assets/questions.json`:

- `text`: open questions answered in your own words
- `who`: "Who is more likely to ..." questions
- `pick`: `["Question", "Option A", "Option B"]`

Keep them friendly for both couples and friends, and write them yourself.

## Reporting security problems

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting on the
repository's Security tab.
