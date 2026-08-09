# ProxyMate

An Android attendance tracker that **assumes you went to class**.

Every class on your timetable is marked present the moment it ends. You open the app only when you *skipped* one. Attendance maintains itself, and the question you actually care about — *how many more can I miss and still hold 75%?* — is answered without a single tap.

Works for any college: you enter your own subjects and your own timetable. No accounts, no server, no internet permission.

---

## Download and test

**[⬇ proxymate-general-arm64.apk](https://github.com/aryanjsawant/ProxyMate---University-Attendance-Marker/raw/master/apk/proxymate-general-arm64.apk)** — 20 MB, start here. Works on any phone from roughly 2017 onward.

| File | Size | Use it if |
|---|---|---|
| [`apk/proxymate-general-arm64.apk`](apk/proxymate-general-arm64.apk) | 20 MB | **Start here** — 64-bit ARM, i.e. essentially every current phone. |
| [`apk/proxymate-general-armeabi-v7a.apk`](apk/proxymate-general-armeabi-v7a.apk) | 17 MB | The arm64 one refused to install (genuinely old 32-bit device). |

From the GitHub web UI: open the file → **Download raw file**.

> These are committed into `apk/` so they can be downloaded straight from the repo. That is a deliberate convenience for testing, not good long-term practice — binaries in git history stay there forever. Once this settles down they belong in a GitHub Release instead, built with `flutter build apk --release --split-per-abi` and attached from `build/app/outputs/flutter-apk/`.

**Installing:** open the file → Android says the source isn't allowed → **Allow from this source** → **Install**. If a "harmful app" screen appears, tap **More details → Install anyway**.

Over USB, which skips both prompts:

```bash
adb install app-arm64-v8a-release.apk
```

> **Runs alongside the `svnit` build.** This branch ships as `com.aryan.proxymate.general`, the SVNIT-tailored branch as `com.aryan.proxymate`. Android keys installed apps by application id, so both install at once. They share a name and icon, so tell them apart by launcher position.

### The "this app may be harmful" warning

It can't be removed, and it isn't a sign anything is wrong. Two prompts are involved: **"Install unknown apps"** is Android's sideloading permission, required for anything not from a store; **Play Protect's "unsafe app"** fires because Google has never scanned this app. Signing with a proper release key does *not* fix the second one — Play Protect warns about unrecognised apps regardless of key. `adb install` avoids both; publishing to Play is the only other route.

---

## Why it exists

Four things every other attendance app gets wrong:

| Problem | What ProxyMate does |
|---|---|
| Can't track two classes of one subject in a day | Each timetable entry is independent. Add the subject twice; mark them separately. |
| You must open the app and tap "present" for every class | Inverted. Presence is assumed; absence is the exception you record. |
| No notifications | End-of-day confirmation, plus an alert the instant an absence drops you below target. |
| No timetable intake | Enter it once; records generate from it. |

Plus the one nobody handles: **teachers ignore the timetable.** Extra classes, cancellations and retroactive corrections are all first-class, not workarounds.

---

## How it works

### The inversion

There is no background service. Android OEMs kill background work aggressively, and silently-wrong attendance is the exact failure this app exists to prevent. Instead **`catchUp()` runs on every app resume**:

1. Walk each date from `max(term.start, lastGenerated)` to today.
2. Skip holidays and anything past `term.end`.
3. For each class whose end time has **already passed**, if no record exists, insert `present`.

Two invariants carry the whole design:

- **Manual always wins.** Generation only ever *inserts where nothing exists*. It never updates or overwrites, so a correction is permanent.
- **Never mark a class that hasn't happened.** Only elapsed classes materialise.

Not opening the app for a week is therefore correct by construction: reopening backfills every elapsed class as present, which is exactly what you meant.

### The data model

```
Subject   name, colour, optional teacher/room, target %   -- the unit of accounting
Slot      subject + weekday + OPTIONAL start/end time     -- one weekly entry
Record    what actually happened: status, manual?, note
Term      start, optional end, target %, holidays
```

Four decisions worth knowing:

- **A lab is just another subject.** There is no course/component nesting. Colleges enforce a separate percentage per registration line, and nesting a lab under a course only ever invited pooling them — which is what lets a healthy lecture percentage hide a failing lab. Create "OS" and "OS Lab" as two subjects.
- **One timetable entry is one attendance.** A two-hour class counts once. A subject meeting twice on a Tuesday is *two entries*. This is why there is no period grid, no span and no unit multiplier.
- **Time is optional.** Entries without a time are marked present at your configured **end of day** (default 6 pm, changeable in More). They still count fully; they just settle later. They sort after timed classes on Home.
- **Records are materialised, not derived.** Editing your timetable in week 8 must not rewrite weeks 1–7. Once a record exists it is frozen history.

### The maths

`lib/logic/stats.dart`, per subject. Let `a` = attended, `h` = held (`present + absent`; **cancelled counts against neither side**), `p` = target, `R` = classes remaining to term end.

| Output | Formula |
|---|---|
| Current % | `a / h` |
| Can miss right now | `floor(a/p) − h` |
| Must attend consecutively to recover | `ceil((p·h − a) / (1 − p))` |
| Can miss across the rest of term | `floor(a + R − p·(h + R))` |
| Best achievable % | `(a + R) / (h + R)` |
| Extra classes needed if unreachable | `ceil((p·(h+R) − (a+R)) / (1 − p))` |

If the target becomes unreachable the UI says so outright — *"75% not reachable — best case 68%"* — rather than showing a cheerful impossible number.

### Notifications

Local only. No Firebase, no server, no account — the **release** manifest declares no internet permission at all. (Debug builds get `INTERNET` from Flutter's own manifests, for hot reload.)

- **End-of-day check** at last-class-end + offset: *"Marked you present for 6 classes today. Miss any?"* The happy path is a dismiss, which is a genuine no-op since present is already the default. This is what makes assuming-present trustworthy.
- **Danger alert** the instant an absence crosses below target. Because presence is assumed, attendance can only *fall* when you mark an absence — so this catches every crossing with no background job.
- **Weekly summary**, Sunday evening.

Attendance correctness never depends on these firing.

---

## Screens

| Screen | Purpose |
|---|---|
| **Home** | Today's classes with an inline P/A/C control (P preselected), a divider, then where every subject stands. At-risk subjects sort to the top and are the only ones coloured. |
| **Subjects** | One card per subject with **one actionable line, not five numbers**. Tap for the full arithmetic and every absence listed. |
| **History** | Month calendar with a dot per class; a filter shows *only days you missed something*. Tap a day to edit it. |
| **More** | Timetable, subjects, the walkthrough, term dates, holidays, target, end-of-day time, notifications, JSON export/import, reset. |

First run is a four-page walkthrough — what the app does, an **interactive P/A/C demo**, subjects, then term dates. Subjects and timetable are both skippable; you can reach a working app in about twenty seconds and fill in the schedule later.

---

## Storage

One JSON document at `getApplicationDocumentsDirectory()/proxymate.json`, written atomically (temp file + rename, so a crash mid-write can't shred the semester). A semester is ~500 records, so SQLite would buy nothing but a schema-migration burden. The real win: **the on-disk format *is* the backup format** — export/import is the same code path as save/load, so a backup can never drift from what the app reads.

---

## Building

```bash
flutter pub get
flutter test          # 83 tests
flutter analyze
flutter run           # phone on USB debugging

flutter build apk --release --split-per-abi
```

Output lands in `build/app/outputs/flutter-apk/`.

### Pinned toolchain — read before changing

`services.gradle.org`, Maven Central and the Gradle Plugin Portal are unreachable from the network this was built on (TCP 443 opens, TLS then dies; only `dl.google.com` and GitHub respond). The Android toolchain is pinned to locally cached versions:

| Piece | Pinned | Why |
|---|---|---|
| Gradle | `8.14.3` | Already extracted in `~/.gradle/wrapper/dists`; 9.1.0 is undownloadable here |
| AGP | `8.11.0` | Cached, and the newest AGP that Gradle 8.14.3 supports |
| Kotlin | `2.1.20` | Cached |
| NDK | `27.1.12297006` | The default `28.2.13676358` is a **failed partial install** — only a `.installer` stub, no `source.properties` |

The NDK override applies to **every** subproject: `path_provider_android` pulls in `jni`, which has native code. It is registered *before* the `evaluationDependsOn(":app")` block, because that block force-evaluates `:app` and `afterEvaluate` throws on an already-evaluated project. Core library desugaring is enabled for `flutter_local_notifications`.

**None of these pins are requirements of the app.** On an unrestricted network they revert to Flutter template defaults.

Release builds are signed with the **debug** key. Fine for sideloading; it is not what triggers the Play Protect warning. One real consequence: the debug keystore is per-machine, so an APK built elsewhere can't upgrade in place.

---

## Tests

83 tests, no device required.

| File | Covers |
|---|---|
| `stats_test.dart` | Every formula, including boundaries: exactly at target, zero held, unreachable target, 100%-with-no-slack, and the floating-point cases where a bare `floor()` costs you a class |
| `attendance_test.dart` | `catchUp` invariants: manual never overwritten, unelapsed classes not materialised, marked-to-the-minute, week-long gap backfill, holidays, idempotence |
| `schedule_test.dart` | Expansion, ordering of timed vs untimed, when each kind of class counts as over, and that length never affects how much a class counts |
| `subject_lifecycle_test.dart` | Add/rename/delete cascades, orphaned slots, `copyDay`, shapes a period grid couldn't express (same-time collisions, odd times, weekends), and save-file round-trips |
| `ui_test.dart` | Real widgets: tapping A records an absence, Undo restores it, cancelling leaves the denominator alone, empty states appear |

The lifecycle suite is the one that matters most. Deleting a subject is where an app like this quietly corrupts itself — orphaned timetable entries, records still counting toward something you can no longer see — so the cascade and its blast radius are pinned hard.

---

## Known gaps

- **Import lives in Settings**, reachable only after setup, so a backup can't be restored on a clean install.
- No iOS target. The engine is portable (pure Dart, no platform checks outside `Notifications`), but iOS builds need a Mac, and free-provisioning sideloads expire after 7 days.
- Deleting a subject deletes its attendance history. The confirm dialog states exactly what goes, but there is no undo.

## Stack

Flutter 3.44 · Riverpod · `flutter_local_notifications` · `table_calendar` · `path_provider` · `share_plus`. No backend, no accounts, no network.

---

## Branches

- **`master`** — this, the general app for any college.
- **`svnit`** — a fork with the SVNIT M.Tech AI timetable, elective pairs and lab batches baked in as seed data. It still uses the older course/component model with a period grid.
