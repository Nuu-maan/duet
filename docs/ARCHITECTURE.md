# Architecture

Duet is a Flutter app for Android backed by Firebase Authentication and the Realtime Database. There is no
server code. Each pair of users owns one Firebase project.

## Stack

- Flutter (stable), Android only, minSdk 24
- `firebase_core`, `firebase_auth`, `google_sign_in`, `firebase_database`, `firebase_messaging`
- `image_picker` for the profile photo
- State with `StreamBuilder` and `ValueNotifier`; no state-management library

## Data model

Everything lives under `/pair` in the Realtime Database.

```
/pair
  /members/{uid}: { name, birthday, photo (base64), photoUrl, online, lastSeen }
  /daily/{yyyy-MM-dd}
    /answers/{uid}: { q0, q1, q2 }
    /chat/q{slot}/{pushId}: { by, text, at }
  /streak: { count, lastDay }
  /rooms/{gameId}: { status, turn, turnNumber, first, state (JSON string), players: { uid: seat } }
  /lists/bucket/{pushId}: { text, done, by }
  /countdowns/{pushId}: { title, date }
  /devices/{uid}: { token, tz, name, birthday, streak, friend, games }   push target and switches
  /nudges/{uid}/{pushId}: { text }       reminder lines the other person wrote for uid
  /notified/{uid}: { nudge, ending, waiting, milestone, last: {...} }    written by the Worker
  /config/notifyUrl                      the Worker's address
```

`database.rules.json` allows reads and writes only for the two UIDs written into it.

## Design decisions

**The rules decide who is allowed.** The app has no list of users. If the database refuses the first read, the
app shows "Not allowed".

**Questions are picked by date.** `QuestionBank.forDay` indexes each list by the number of days since
2026-01-01, so both phones show the same three questions with no server. Editing the lists changes what past
days display.

**Game state is one JSON string.** The Realtime Database turns sparse lists into maps and drops empty ones.
Storing the state as a string keeps it atomic and predictable.

**Every move is a transaction that re-runs the rules.** `playMove` in `lib/games/room.dart` decodes the room,
applies `Game.move` and aborts if it returns `null`. Out-of-turn and illegal moves are rejected even when both
phones write at once. The streak uses a transaction for the same reason.

**Presence.** `Presence` in `lib/pair.dart` listens to `.info/connected`, registers an `onDisconnect` write and
takes the database offline when the app is backgrounded, so the other person sees you go offline within seconds.

**Profile photos are stored in the database.** The free plan has no file storage. Photos are resized to 256 px,
capped at 60 KB and stored as base64 on the member record.

**Pictures are drawn in code.** `lib/art.dart` paints the mascot and uses Material icons for the rest. The app
ships no image assets, which keeps the APK small and avoids licensing questions.

## Notifications

Notifications are optional and live in `worker/`, a Cloudflare Worker.

- `worker/src/rules.js` is pure: given the pair's data and the current time it returns the pushes to send. All
  message texts are there. `worker/test/` covers it; run `node --test` in `worker/`.
- `worker/src/index.js` does the I/O. A cron trigger runs every 15 minutes for timed reminders. `POST /event` is
  called by the app after an answer, a chat message or an accepted game move; it verifies the caller's Firebase ID
  token and requires the caller to have a device record, which only the two allowed accounts can write.
- Nothing is scheduled on the phone, so a notification can never show stale data. `/notified` records what was
  sent so each timed reminder goes out at most once a day and wording does not repeat.
- The Worker authenticates to Firebase with a service account key held as a Wrangler secret.

## Keeping it light

- Game boards are a `CustomPainter` inside a `RepaintBoundary`, repainted from a `ValueNotifier`; the screen
  does not rebuild on every move.
- Database listeners are created per screen and cancelled on dispose.
- Implicit animations by default; durations and curves are listed in `.claude/rules/ui.md`.
- Always judge performance with `flutter run --release` on a real phone.

## Known shortcuts

Search the code for `shortcut:`. Each one names its limit and when to upgrade it:

- Battleship fleets are placed at random
- Past days and the inbox load a fixed number of recent days
- Hidden information is hidden by the UI, not by database rules
