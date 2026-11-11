# Chalk

A training log for one person's pull/push/legs plan. Android and the browser,
Flutter, offline. Nothing leaves the device unless you export it.

It is a log rather than a workout app: it does not prescribe programmes, and it
does not guess. Where it cannot work something out it says so instead of
inventing a number.

## What it does

- **Logs sessions** against a plan of routines, with per-set weight, reps, RPE,
  hold time or descent tempo depending on what the movement is measured in.
- **Progresses the load for you** when the rule is actually met, and explains
  itself when it is not.
- **Reads the log back**: volume by muscle against weekly landmarks, estimated
  1RM curves, which lifts are moving and which are stuck.
- **Tracks goals** with markers pulled from the log rather than typed in.
- **Warm-up ramps, plate maths, rest timers, substitutions** for when the
  machine you wanted is taken.

## The ideas worth knowing

A few decisions explain most of the code.

**Load is not the number you typed.** `effectiveLoad` in
[lib/data/progression.dart](lib/data/progression.dart) converts a logged number
into real resistance. Dumbbells log per side and count double. An assistance
machine is inverted — bodyweight *minus* the help, so dropping the stack is
progress. A plate-loaded machine's logged number already contains its sled, so
the sled is never added on top. Everything downstream — volume, e1RM, records,
goal markers — is built on that one function.

**Progression is double, and gated on RPE.** Every set at the top of the rep
range *and* a last set at RPE 8 or easier earns more weight. Reps hit but no RPE
logged earns nothing, because "I finished all the reps" does not say whether it
was hard. Changing the load, missing a rep or leaving RPE blank restarts the
count. See `adviseProgression`.

**Volume is counted in hard sets per week**, not tonnage, judged against
maintenance / minimum-effective / productive-ceiling landmarks. Muscles worked
as synergists bank half a set: a bench press really does train triceps, just not
as its main job.

**Trends measure the last session that *beat* everything before it**, not the
last one that matched it. Repeating a number you already hit is the shape of a
stall, so `[100, 100, 100, 100]` reads as stuck rather than as holding steady.

**The preview cannot lie.** "See the numbers first" builds the same
`SessionExercise` objects a real session builds and throws them away, so what it
shows is what pressing Start produces. There is one code path, not two.

## Running it

```bash
flutter pub get
flutter run                     # debug, on a connected device or emulator
flutter test                    # 317 tests
flutter analyze
flutter build apk --release
flutter build web --release     # the browser version, into build/web
```

Installing a **debug** build over a release one wipes the log, so update a real
device with a release build:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Layout

```
lib/
  models/models.dart      Plain data: exercises, plan, sessions, goals, settings
  data/
    app_state.dart        The store. Split across `part` files, one library, so
    app_state_*.dart        privacy still works: sessions, stats, goals, io,
                            library. Every mutation funnels through _touch.
    progression.dart      Load maths, progression rules, warm-up ramps,
                            volume landmarks, trend verdicts. No Flutter.
    storage.dart          One JSON document, written atomically
    storage_web.dart      The same document in IndexedDB, for the browser
    seed.dart             The plan and exercise library this install ships with
    rest_timer.dart       Rest countdown, live notification, wakelock
    notifications.dart    Rest alerts and scheduled training reminders
  ui/                     One file per screen, widgets/ for the shared pieces
  utils/                  Formatting and the plate calculator
test/
  helpers.dart            In-memory storage and fixtures every test file shares
  *_test.dart             One file per area; pages_test.dart holds the widget
                            tests, the rest are logic
```

`progression.dart` deliberately imports no Flutter, so the training rules can be
read and tested without a widget in sight.

## Your data

Everything lives in one JSON document in the app's private storage. Writes go to
a temp file and rename over the top, so a crash can never leave half a database.
A snapshot is taken after every finished workout, keeping the last ten.

**Those snapshots are on the phone.** They rescue a bad import; they do not
survive losing the device. Settings nags you when nothing has been exported off
the phone in a fortnight — that export is the one that matters.

- **Export backup** — JSON, restores everything.
- **Export the log as CSV** — one row per set for a spreadsheet. A way out, not
  a way back in, so it deliberately does not count as a backup.

A backup written by a newer version of the app is refused rather than opened,
because opening it would silently drop whatever that version added. Raise
`Storage.schemaVersion` only for a change an older build would get *wrong*.

## The browser version

The same app, built for the web and published to GitHub Pages by
[.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml) on every
push to `main`. It can be added to a phone's home screen and run like an app.

There is no server. The browser build keeps the same JSON document in the
browser's own database (IndexedDB) instead of a file — see
[lib/data/storage_web.dart](lib/data/storage_web.dart) — so its log is separate
from the phone's. Move between them with Export / Import backup.

Browser storage is more fragile than a file on a phone:

- **Clearing site data or cookies deletes it**, and a private window forgets it
  on close.
- **Safari deletes it after seven days without a visit**, unless the page has
  been added to the home screen.
- **It belongs to one browser at one address.** Chrome cannot see Edge's copy,
  and moving the site to another URL leaves the data behind.

After the first finished workout the app asks the browser to keep its data
through low-disk clean-ups (Chrome decides by itself, Firefox asks). Exports
download as files. The status-bar timer and the training reminders are phone
features and are hidden in the browser.
