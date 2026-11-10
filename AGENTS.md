# Notes for AI coding agents

Read `README.md`, `CONTRIBUTING.md` and `docs/ARCHITECTURE.md` first. The rules in `CONTRIBUTING.md` apply to you
exactly as they apply to human contributors.

- Free only, light, two people. Do not add sign-up flows, pairing codes, paywalls, ads or analytics.
- Original material only. Never add text, art, fonts or code taken from another app.
- UI, motion and performance rules are in `.claude/rules/ui.md`.
- Dart package name is `duet`. The default Android application ID is `dev.duet.app`.
- Never commit `android/app/google-services.json`, `shorebird.yaml` or a Firebase service account key.
- Work on a branch and open a pull request; do not push to `main`. Keep commits small.
- Do not write code comments unless leaving one out would let someone silently break something. A one-line
  `shortcut: <the limit>, <when to upgrade>` comment is allowed where a known shortcut was taken.
- Write a unit test for any non-trivial logic. Run `dart format lib test`, `flutter analyze` and `flutter test`
  before finishing.
