# Publishing to Google Play

Everything in the repo is ready. What remains is an account, a signing key, and
Google's paperwork.

The long pole is **not** engineering: a personal developer account created after
November 2023 must run a **closed test with 12+ testers who stay opted in for 14
continuous days** before it can apply for production access. Start that clock
early — everything else fits around it.

---

## 1. Create the signing key — once, and never lose it

```bash
keytool -genkey -v -keystore ~/proxymate-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
in the passwords. That file and `*.jks` are gitignored.

**Back the `.jks` up somewhere that is not this laptop.** With Play App Signing
(the default for new apps) Google holds the real signing key and yours is only
an *upload* key, so a lost key is a support request rather than a dead app —
but it is still a bad day.

Verify the release build is no longer debug-signed:

```bash
flutter build apk --release
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The owner should be what you typed into `keytool`, not `CN=Android Debug`.

## 2. Build the bundle

Play takes `.aab`, not `.apk`:

```bash
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

## 3. Developer account

- <https://play.google.com/console> — **$25, one time.**
- Choose **personal** or **organisation**. Organisation skips the 12-tester
  requirement but needs a D-U-N-S number.
- Identity verification: government ID and address. For personal accounts that
  address is **shown publicly on the listing**; a PO box is allowed.

## 4. Store listing

| Field | Value |
|---|---|
| App name | ProxyMate |
| Short description | see below (≤80 chars) |
| Full description | see below (≤4000 chars) |
| App icon | `docs/store/icon-512.png` |
| Feature graphic | `docs/store/feature-graphic.png` |
| Phone screenshots | `docs/screenshots/*.png` — at least 2, up to 8 |
| Category | Education |
| Contact email | required, shown publicly |
| Privacy policy URL | see step 5 |

### Short description (73 characters)

```
Attendance that assumes you went. Only mark the classes you skipped.
```

### Full description

```
ProxyMate is an attendance tracker built on one idea: you almost always go to
class, so the app should assume it.

Every class on your timetable is marked present the moment it ends. You never
open the app to say you attended — only when you skipped. A perfect week costs
you zero taps.

WHAT IT TELLS YOU

• How many more classes you can miss and still hold 75%
• Or, if you have slipped, exactly how many you must attend to climb back
• Whether 75% is still reachable at all — it says so plainly instead of showing
  a cheerful impossible number
• How many classes are left this term, if you set an end date

BUILT FOR HOW COLLEGES ACTUALLY WORK

• Two classes of the same subject in one day, tracked separately
• Labs as their own subject, with their own attendance requirement
• Extra classes teachers add off the timetable
• Cancelled classes, which count against neither side
• Whole days off, and date ranges for mid-term breaks
• Any past record editable, any day, any time
• One attendance target for the term, adjustable if yours is not 75%

SET IT UP MID-TERM

Enter your subjects and timetable, set the start date, and every class between
then and today is filled in for you. Correct the ones you missed and you are
up to date.

REMINDERS

An end-of-day nudge to fix anything the app got wrong, a warning the moment a
subject drops below your target, and a weekly summary. All scheduled by your
phone.

COMPLETELY OFFLINE

No account. No sign-in. No ads. No analytics. The app does not request internet
permission at all, so your attendance cannot leave your phone even in
principle. Back it up yourself with a single JSON file whenever you like.
```

## 5. Privacy policy URL

`docs/privacy-policy.md` is written. Publish it by enabling **GitHub Pages** on
the repo (Settings → Pages → deploy from `master`, `/docs`), which gives you:

```
https://aryanjsawant.github.io/ProxyMate-University-Attendance-Marker/privacy-policy
```

## 6. Data safety form

Declare **no data collected** and **no data shared**. Every question resolves to
"no". The absence of an internet permission is unusually strong evidence, and
is worth mentioning if a reviewer ever queries it.

## 7. Content rating

Fill in the questionnaire: no violence, no user content, no ads, no purchases,
no data sharing. Result should be Everyone / PEGI 3.

## 8. App content declarations

- **Target audience**: 13+. Declaring under-13 pulls you into Families policy
  for no benefit.
- **Ads**: none.
- **App access**: no login, so nothing to give reviewers.
- **Government app**: no.
- **Financial features**: none.
- **Data deletion**: no account exists; uninstalling removes everything.

## 9. Closed test — the 14-day clock

Create a **Closed testing** track, upload the `.aab`, and add 12+ testers by
email or Google Group. They must **install and stay opted in for 14 continuous
days**. Only then does "Apply for production" unlock.

Use this time for the thing tests cannot cover: confirm the **end-of-day
notification actually fires** on a range of phones. Xiaomi, Oppo, Vivo and
Realme kill background alarms aggressively, and that is exactly the behaviour
no unit test can prove.

## 10. Production

Promote the closed-test release to Production. First review typically takes a
few days; later updates are usually faster.

---

## Versioning

`versionCode` and `versionName` come from `pubspec.yaml`'s `version: 1.0.0+1`.
Play rejects a `versionCode` it has already seen, so bump the number after the
`+` for every upload:

```yaml
version: 1.0.1+2
```
