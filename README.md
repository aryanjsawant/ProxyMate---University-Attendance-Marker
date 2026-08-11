# ProxyMate

An Android attendance tracker that **assumes you went to class**.

Every scheduled class is marked present the moment it ends. You open the app only when you *skipped* one. Attendance maintains itself, and the question you actually care about — *how many more can I miss and still hold 75%?* — is answered without a single tap.

> **This is the `svnit` branch.** The class timetable, elective pairs and lab batches of the SVNIT B.Tech AI programme are baked in as seed data, so setup is roughly zero taps. Everything except `lib/data/seed_tt.dart` is institution-agnostic — see [What's SVNIT-specific](#whats-svnit-specific) before generalising on `master`.

---

## Download

**[⬇ Latest APK — GitHub Releases](https://github.com/aryanjsawant/ProxyMate---University-Attendance-Marker/releases?q=svnit&expanded=true)**

Grab the file ending **`-arm64.apk`** — right for essentially every phone made since 2017.

Open it on your phone → Android blocks it → **Allow from this source** → **Install**. If a "harmful app" screen appears, tap **More details → Install anyway**; that is normal for anything not distributed through the Play Store, and is not a signal about this app in particular.

Releases from this branch are tagged `svnit-v*` so they never collide with the general app's.

> **Installs alongside the general build.** This one is `com.aryan.proxymate`, the general app is `com.aryan.proxymate.general`, so you can run both.

---

## Setup, for an SVNIT B.Tech AI student

The class timetable is already in the app. Setup is three screens:

1. **Electives** — pick your side of each shared slot: B (AC / PGM), C (IR / IoT & EC), D (AIFS / ABSS), E (ILLM / Agentic AI), and whether you take the honours AI411.
2. **Lab batch** — Batch-I (Monday 2:00–3:50) or Batch-II (Monday 4:00–5:50).
3. **Term dates** — everything from the start date to today is filled in as present the moment you finish.

Then correct the classes you actually missed from History.

---

## Why it exists

Four things every other attendance app gets wrong:

| Problem | What ProxyMate does |
|---|---|
| Can't track two sessions of one subject in a day | Sessions are independent records. Thursday's two honours classes are two rows you can mark differently. |
| You must open the app and tap "present" for every class | Inverted. Presence is assumed; absence is the exception you record. |
| No notifications | End-of-day confirmation, plus an alert the instant an absence drops you below target. |
| No timetable intake | The timetable is entered once (or imported); records generate from it. |

Plus the one nobody handles: **teachers ignore the timetable.** Extra classes, cancellations and retroactive corrections are all first-class, not workarounds.

---

## How it works

### The inversion

There is no background service. Android OEMs kill background work aggressively, and silently-wrong attendance is the exact failure this app exists to prevent. Instead, **`catchUp()` runs on every app resume**:

1. Walk each date from `max(term.start, lastGenerated)` to today.
2. Skip holidays and anything past `term.end`.
3. For each slot whose end time has **already passed**, if no record exists for `(date, slot)`, insert `present`.

Two invariants carry the whole design:

- **Manual always wins.** Generation only ever *inserts where nothing exists*. It never updates or overwrites, so a correction is permanent.
- **Never mark a class that hasn't happened.** Only elapsed slots materialise. Today's later classes show as upcoming until they end.

Not opening the app for a week is therefore correct by construction: reopening backfills every elapsed slot as present, which is exactly what you meant.

### The data model

Scheduling is **slot-driven, not time-driven** — a course occupies a slot, and a slot maps to fixed `(weekday, period)` meetings. This is what makes elective pairs, timetable sharing and mid-semester changes clean.

```
Period      the bell schedule: index -> start/end minutes
Course      a subject; may belong to an electiveGroup
Component   Course x {theory, lab} -- the real unit of accounting
Slot        one timetable cell: component, weekday, periodIndex, spanPeriods
Occurrence  a Slot resolved onto a concrete date (generated, never stored)
Record      what actually happened: status, units, manual?, note
Term        start, optional end, target %, holidays
```

Four decisions worth knowing:

- **Theory and lab are separate `Component`s under one `Course`.** Every percentage, budget and alert is computed per component, never pooled — because that's how universities enforce it. A healthy lecture percentage must not be able to hide a failing lab.
- **Tutorials fold into theory.** For a 3-1-0 course the tutorial is the same registration line. `Slot.isTutorial` is a display label, not a separate component.
- **Electives are a filter, not separate timetables.** The timetable holds *both* sides of each pair; `enrolledCourseIds` decides which generates records. So one person enters it and everyone imports it, and switching an elective in week 2 re-enters nothing.
- **Records are materialised, not derived.** Editing your timetable in week 8 must not silently rewrite weeks 1–7. Once a record exists it is frozen history.

**Everything is counted in units, not rows.** A two-period lab writes `units: 2`, so one lab absence correctly costs twice a lecture absence.

### The maths

`lib/logic/stats.dart`, per component. Let `a` = attended units, `h` = held units (`present + absent`; **cancelled counts against neither side**), `p` = target, `R` = units remaining to term end.

| Output | Formula |
|---|---|
| Current % | `a / h` |
| Can miss right now | `floor(a/p) − h` |
| Must attend consecutively to recover | `ceil((p·h − a) / (1 − p))` |
| Can miss across the rest of term | `floor(a + R − p·(h + R))` |
| Best achievable % | `(a + R) / (h + R)` |
| Extra classes needed if unreachable | `ceil((p·(h+R) − (a+R)) / (1 − p))` |

If the target becomes unreachable the UI says so outright — *"75% is no longer reachable; best case 68%"* — rather than displaying a cheerful impossible number.

### Notifications

Local only. No Firebase, no server, no account — the **release** manifest declares no internet permission at all, which is the strongest guarantee that attendance data never leaves the phone. (Debug and profile builds get `INTERNET` from Flutter's own manifests, for hot reload.)

- **End-of-day check**, fired at last-class-end + offset: *"Marked you present for 6 classes today. Miss any?"* The happy path is a dismiss, which is a genuine no-op since present is already the default. This is what makes assuming-present trustworthy.
- **Danger alert**, the instant an absence crosses below target. Because presence is assumed, attendance can only *fall* when you mark an absence — so this catches every crossing with no background job.
- **Weekly summary**, Sunday evening.

Attendance correctness never depends on these firing. They're a convenience layer over `catchUp()`, so OEM battery-killers can delay them without making the data wrong.

---

## Screens

| Screen | Purpose |
|---|---|
| **Home** | Today's classes with an inline P/A/C control (P preselected), a divider, then where every subject stands. At-risk components sort to the top and are the only ones coloured. |
| **Subjects** | One card per component, grouped by course. **One actionable line, not five numbers.** Tap for the full arithmetic. |
| **History** | Month calendar with a dot per class; a filter toggle shows *only days you missed something*. Tap a day to edit it. |
| **More** | Timetable editor, electives/batch, term dates, holidays, target, notifications, JSON export/import, reset. |

The design principle: you open this app for two reasons — *"am I safe?"* and *"I bunked, log it"*. Home answers the first without a tap and the second in one.

`lib/screens/day_editor.dart` is what makes teacher deviations survivable — extra classes, cancellations, whole-day and date-range operations all live there.

---

## Storage

One JSON document at `getApplicationDocumentsDirectory()/proxymate.json`, written atomically (temp file + rename, so a crash mid-write can't shred the semester).

A semester is ~500 records, so SQLite would buy nothing but a schema-migration burden. The real win: **the on-disk format *is* the backup format** — export/import is the same code path as save/load, so a backup can never drift from what the app actually reads.

---

## Building

```bash
flutter pub get
flutter test          # 68 tests
flutter analyze
flutter run           # phone on USB debugging

# Release
dart run tool/make_icon.dart        # regenerate icon source PNGs
dart run flutter_launcher_icons     # write Android mipmaps
flutter build apk --release --split-per-abi
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~19 MB). The universal `app-release.apk` (~54 MB) installs anywhere if the split one refuses.

Release builds are signed with the **debug** key. That's fine for sideloading — it is *not* what triggers the Play Protect warning ([see above](#about-the-this-app-may-be-harmful-warning)) — but it has one real consequence: the debug keystore lives at `~/.android/debug.keystore` and is per-machine, so an APK built on a different machine can't upgrade in place. Set up a real keystore if you ever build from more than one machine, or intend to publish.

### Pinned toolchain — read before changing

`services.gradle.org`, Maven Central and the Gradle Plugin Portal are unreachable from the network this was built on (TCP 443 opens, TLS then dies; only `dl.google.com` and GitHub respond). The Android toolchain is therefore pinned to what was already cached locally:

| Piece | Pinned | Where | Why |
|---|---|---|---|
| Gradle | `8.14.3` | `gradle-wrapper.properties` | Already extracted in `~/.gradle/wrapper/dists`; 9.1.0 is undownloadable here |
| AGP | `8.11.0` | `android/settings.gradle.kts` | Cached, and the newest AGP that Gradle 8.14.3 supports |
| Kotlin | `2.1.20` | `android/settings.gradle.kts` | Cached |
| NDK | `27.1.12297006` | `android/build.gradle.kts` + `app/build.gradle.kts` | The default `28.2.13676358` is a **failed partial install** — only a `.installer` stub, no `source.properties` |

The NDK override applies to **every** subproject, not just `:app`: `path_provider_android` pulls in `jni`, which has native code. It is registered *before* the `evaluationDependsOn(":app")` block, because that block force-evaluates `:app` and `afterEvaluate` throws on an already-evaluated project.

Core library desugaring is enabled — `flutter_local_notifications` requires it.

**None of these pins are requirements of the app.** On an unrestricted network they can all revert to Flutter template defaults.

---

## Tests

68 tests, no device required.

| File | Covers |
|---|---|
| `stats_test.dart` | Every formula, including boundaries (exactly at target, zero held, unreachable target, 100%-with-no-slack) |
| `attendance_test.dart` | `catchUp` invariants: manual never overwritten, unelapsed slots not materialised, gap backfill, holidays |
| `timetable_fidelity_test.dart` | The seed timetable matches the printed sheet: 23 periods/week (27 with honours), tutorial polarity, 2-unit labs, twice-daily sessions |
| `ui_test.dart` | Real widgets: tapping A records an absence, Undo restores it, cancelling leaves the denominator alone, theory/lab render separately |

`timetable_fidelity_test.dart` is the one that matters most on this branch — it's the executable transcription of the printed timetable.

---

## What's SVNIT-specific

Everything below is confined to **`lib/data/seed_tt.dart`** plus a handful of references:

- 8 periods (8:30–9:20 … 5:00–5:50), lunch 12:20–2:00
- Slot letters A/B/C/D/E/H and lab slots P7/P8/P11/P12
- Elective pairs: B = AC/PGM, C = IR/IoT&EC, D = AIFS/ABSS, E = ILLM/Agentic AI
- `seedDefaultEnrolledCourseIds` — the branch owner's own registration
- Batch-I / Batch-II for the Monday IMAES lab
- Copy in `setup_wizard.dart` referencing "B.Tech AI timetable"
- `timetable_fidelity_test.dart`, which asserts this exact timetable

**To generalise on `master`**, the work is roughly:

1. Ship no seed timetable; open the wizard on *"Build your timetable"* vs *"Import a class timetable"*.
2. Make the period schedule user-defined (count and times) — the model already supports this; only the wizard hardcodes 8.
3. Make elective groups an optional concept. Institutions without slot-sharing should never see the word.
4. Replace `seedDefaultEnrolledCourseIds` with an empty default.
5. Keep `timetable_fidelity_test.dart` as a fixture-driven test over a sample timetable rather than *the* timetable.

The core — `logic/`, `models/`, `state/`, `screens/`, `widgets/` — needs no changes. It was written against the general model, and SVNIT's timetable is just one instance of it.

### Known gaps

- **Import lives in Settings**, reachable only after setup — so a backup can't be restored on a clean install. Needs a "Restore from backup" entry on the wizard's first screen.
- The setup wizard defaults the lab batch to the first one; Batch-II users must change it.
- No iOS target.

---

## Stack

Flutter 3.44 · Riverpod · `flutter_local_notifications` · `table_calendar` · `path_provider` · `share_plus`. No backend, no accounts, no network.
