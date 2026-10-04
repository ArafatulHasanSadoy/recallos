# Releasing RecallOS

How to get a build onto Google Play, and what has to be true before you do.
Written on 2026-09-08, against Play's rules as they stood that day.

Everything here has been done once except the parts marked **yours** — those
need an account, a payment method, or a government ID, and none of that can be
automated.

---

## Before the first upload, once

### 1. The upload key — yours

Play refuses a debug certificate. Generate a keystore, **outside the repo**:

```bash
keytool -genkey -v -keystore ~/recallos-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then write `android/key.properties` — gitignored, along with `*.jks` and
`*.keystore`:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/you/recallos-upload.jks
```

Use an **absolute** `storeFile` path. A relative one resolves against
`android/app/`, which is not where anybody keeps a keystore.

`android/app/build.gradle.kts` reads this file. **Without it a release build
refuses to sign** and says why, instead of quietly using the debug key. For a
release build that will never be uploaded — the R8 checks on your own phone,
CI, the benchmark APK — opt in explicitly:

```bash
RECALLOS_ALLOW_DEBUG_SIGNING=true flutter build appbundle --release
```

Play rejects a debug certificate, so an opted-in build still cannot be uploaded
by accident; the refusal just moves that failure from upload time to build
time, where it is cheap.

> **Back up `recallos-upload.jks` and both passwords somewhere that is not this
> laptop.** Losing them locks you out of updating your own app. Play App Signing
> (accept it when Console offers it) lets Google reset the *upload* key if that
> happens, which is a safety net, not a substitute.

### 2. The privacy policy — done, keep it true

**Live** at `https://arafatulhasansadoy.github.io/recallos/privacy-policy.html`
(checked 2026-09-28, HTTP 200). What is still owed: it has to be rewritten when
the profile ships (it says there are no user profiles), when the on-device
language-model sentence is removed, and before any release that brings back
`INTERNET`.

`docs/privacy-policy.html` is written. Play requires a policy URL for every
app, including one that collects nothing, and it must be reachable by anyone
without logging in — a Google Doc link or a file on your laptop will not do.

GitHub Pages serves it for free because `ArafatulHasanSadoy/recallos` is
public. (On a private repo, Pages needs a paid plan.)

1. **Commit and push.** Pages publishes what is on GitHub, not what is on your
   laptop — an uncommitted file does not exist as far as it is concerned.
2. On github.com, open the repo → **Settings** (the tab, not your account
   settings) → **Pages** in the left sidebar.
3. Under **Build and deployment** → **Source**, choose **Deploy from a branch**.
4. Under **Branch**, pick `main`, then change the folder dropdown from
   `/ (root)` to **`/docs`**, and press **Save**.
5. Wait a minute or two. A green banner appears at the top of that page with
   the site URL. The build also shows up under the repo's **Actions** tab if
   you want to watch it.
6. Open `https://arafatulhasansadoy.github.io/recallos/privacy-policy.html`
   and check it actually loads before pasting it into Play Console.

`docs/.nojekyll` is what makes step 5 reliable: without it GitHub runs the
files through Jekyll, which is a site generator this project has no use for and
which can fail the build over something unrelated. The empty file turns it off,
and the folder is served exactly as it is.

Note that everything else in `docs/` is published at that site too —
`PLAN.md` and this file included. The repo is public, so nothing is newly
exposed, but do not put anything in `docs/` you would not want served.

### 3. The developer account — yours

1. <https://play.google.com/console/signup>, signed in as the Google account
   that should own this permanently. Moving an app between accounts later is
   painful.
2. **2-Step Verification must be on for that account first** — registration
   refuses without it.
3. Choose **Personal**. (An Organization account needs a D-U-N-S number and a
   legal entity, and is what exempts you from the 12-testers rule below. For a
   university project, Personal is right.)
4. Pay the one-time **$25**.
5. **Identity verification**: legal name and address matching a passport or
   national ID, plus a phone number. The name and address in Console must match
   the document. This takes anywhere from hours to several days, and **nothing
   can be uploaded until it clears** — so start it before you need it.

**Know what a Personal account publishes.** It shows your legal name, country
and developer email — and **once you sell anything, your full address**. The
Lifetime purchase planned for 499B triggers that. If a home address on a public
listing is not acceptable, the way out is an Organization account (trade
licence + D-U-N-S number, which can take up to 30 days), and the app can be
moved later with Play's official transfer feature (7-day cool-down). Whether a
business address can stand in on a Personal account is unverified.

**Package registration.** Android developer verification now requires every
Play package to be registered to a verified developer; new apps are registered
as part of publishing. Enforcement for sideloaded installs reaches Bangladesh
in 2027 — demo APKs for examiners will then need the free *limited distribution*
registration (up to 20 devices).

### 4. The merchant payments profile — yours, before anything is sold

Bangladesh is a supported merchant location; sales settle in **USD** by wire to
a bank account in the same country as the payments profile, monthly, above a
US$100 threshold. Submit a **W-8BEN** in the payments profile, or US-user
revenue is withheld at the default 30%. Enrol in the **15% service-fee tier**
(it is not automatic: create an Account Group once). Google collects and remits
VAT for Bangladeshi buyers.

Which payment methods Bangladeshi buyers actually have in Play (bKash, carrier
billing) is **unverified** — try a purchase from a Bangladeshi account during
closed testing before planning prices around it.

---

## Every release

### Bump the version

`pubspec.yaml`:

```yaml
version: 1.0.0+1
#       ^name ^code
```

**Play requires a strictly higher `versionCode` for every upload, forever** —
including a re-upload of identical code after a rejection. Bump the number after
the `+`. The name before it is what users see and can stay put.

### Build the bundle

```bash
flutter build appbundle --release --dart-define=RECALLOS_COMMIT=$(git rev-parse --short HEAD)
```

The define stamps the commit into Settings → About and into feedback emails,
so a tester's report names the exact code. Leave it off and the app says
"local". **Never** add `--dart-define=RECALLOS_BENCH=true` to a build meant for
Play — that is the benchmark build, with the evaluation screen compiled in.

Output: `build/app/outputs/bundle/release/app-release.aab`. Play requires an
App Bundle for new apps; a plain APK is not accepted.

Note that a bundle build is **not** the same R8 run as
`flutter build apk --split-per-abi` — Flutter disables `shrinkResources` for
split APKs and leaves it on for a bundle. R8 has silently broken this project
before (`android/app/proguard-rules.pro` documents ML Kit's registrars being
renamed, which made OCR return zero blocks in release while debug was fine), so
a green build is not evidence. Verify on the artifact.

### Verify the artifact, not the source

```bash
# Turn the bundle into an installable APK — the same code Play will deliver.
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/recallos.apks --mode=universal
unzip -o -p /tmp/recallos.apks universal.apk > /tmp/recallos-universal.apk

# Permissions, read from the bundle itself and compared with the allowlist.
# Expect exactly: CAMERA, USE_BIOMETRIC, USE_FINGERPRINT, the app's own
# DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION, and — since reminders (A2, 30 Sep)
# — POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED and VIBRATE, and since RecallOS
# Plus (A7, 4 Oct) com.android.vending.BILLING. No INTERNET, no RECORD_AUDIO,
# no SCHEDULE_EXACT_ALARM or USE_EXACT_ALARM. Play Billing talks to the Play
# Store app on the phone, which does the networking; the app does none.
# (The AICore BIND_SERVICE permission left with flutter_local_ai, 2026-09-28.)
# CI runs the same script on every push.
tool/ci/check_permissions.sh

# 16 KB pages: every native library must pass (required from 1 Feb 2027).
zipalign -c -P 16 -v 4 /tmp/recallos-universal.apk | grep '\.so'

# The signature must be yours, not CN=Android Debug. Check the BUNDLE, not the
# APK: bundletool signs the APKs it generates with its own debug keystore
# regardless of how the bundle was signed, so `apksigner` on the universal APK
# always says "Android Debug" and tells you nothing.
jarsigner -verify -verbose:summary -certs \
  build/app/outputs/bundle/release/app-release.aab | grep -A1 'Signer'
```

Then install that universal APK and **scan a card end to end** — capture, OCR,
correct a field, add a note, search for it. That is the path R8 breaks, and the
only way to know it did not.

`flutter analyze` clean and `flutter test` green before any of this counts.

---

## Uploading

### Internal testing — the fast track

**Test and release → Testing → Internal testing → Create new release.**

- Accept **Play App Signing** when prompted.
- Upload the `.aab`.
- Release notes can be one sentence.
- **Save → Review release → Start rollout to Internal testing.**

Then **Testers** → create an email list → add up to 100 Google accounts → copy
the **opt-in URL** and send it out. Testers open it, click *Become a tester*,
and install from Play. Builds appear within minutes, and internal testing skips
the standard policy review.

Testers must use the exact Google account you listed. This trips everyone once.

Internal testing works with the app only partly configured — the store listing
and content declarations can wait. Everything below is required before closed
testing or production.

### The App content declarations

**Policy → App content.**

| Section | Answer |
|---|---|
| Privacy policy | the GitHub Pages URL above |
| Ads | No |
| App access | All functionality available without special access — the wallet lock is off by default (`app_settings.dart`, `lockEnabled: false`), so a fresh install opens with no gate |
| Content rating | IARC questionnaire; a utility with no objectionable content |
| Target audience | 18+, with Restrict Minor Access — keeps the app clear of the Families policy |
| News app | No |
| Government / health | No to both. The **Health apps** declaration still has to be completed |
| Financial features | **Re-answer when spending totals ship.** Expense tracking from saved receipts is not lending or trading, but which category Play expects for it is unverified — read the options and answer truthfully |
| Data safety | see below |

### Data safety — the one that matters

A wrong answer here is itself a policy violation, so the reasoning is recorded
rather than just the answer.

Google defines *collect* as **transmitting data off the user's device**: *"User
data accessed by your app that is only processed locally on the user's device
and not sent off device does not need to be disclosed."*

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any user data? | **No** | Nothing is transmitted. The release build has no `INTERNET` permission, verified with `aapt dump permissions` |
| Encrypted in transit | n/a | Follows from the above |
| Data deletion mechanism | n/a | No accounts, no server copy. Uninstalling deletes everything, key included |
| Privacy policy URL | as above | Required even at "no data collected" |

**Be ready to defend one point.** Sharing a vCard, or tapping a number to open
WhatsApp or an address to open Maps, hands data to another app. Google's own
exception covers it: *"transferring user data to a third party based on a
specific user-initiated action, where the user reasonably expects the data to be
shared."* Each of those is a deliberate tap on a control that says what it does,
so **No data shared** is the correct answer.

### Store listing assets

Required before closed testing, not before internal.

| Asset | Requirement | Where |
|---|---|---|
| Icon | 512×512, 32-bit PNG **with alpha**, ≤1024 KB | `assets/brand/png/appicon-512-play.png` — ready. (`appicon-512.png` is the App Store one and has *no* alpha, which Apple requires and Play rejects; they cannot be the same file) |
| Feature graphic | 1024×500, JPEG or 24-bit PNG, no alpha | `store/feature-graphic.jpg` — ready (2026-10-04) |
| Phone screenshots | 2–8, each side 320–3840 px | `store/screenshots/` — six, 1080×1920, real RMX3612 screens with demo cards and a caption each — ready (2026-10-04) |
| Short description | ≤80 characters | `store/listing.md` — ready |
| Full description | ≤4000 characters | `store/listing.md` — ready; every claim checked against the build |

---

## Getting to production

Production is a separate gate, and on a **personal** account created after
13 November 2023 it requires:

1. A **closed test with at least 12 testers opted in continuously for 14 days**.
   A tester who opts out and rejoins restarts their own clock.
2. **Apply for production access** from the Console dashboard — three sections
   about how you tested and what testers said. Review typically takes about a
   week.
3. The complete store listing and every App content declaration above.
4. A full policy review, which internal testing skipped.

Start the 14-day clock as soon as a closed-testing build is up; it runs in the
background while the rest gets finished.

---

## Two things that will bite

### Changing the signing key means uninstalling

A build signed with the upload key cannot install over one signed with the debug
key — Android refuses with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only
way through is to uninstall.

**Uninstalling destroys the wallet permanently, and a file copy does not save
it.** The SQLCipher key lives in `flutter_secure_storage` → the Android
Keystore, which is wiped with the app; a copied `.sqlite` comes back as
`StorageProtection.unreadable`. `run-as` also refuses a non-debuggable package,
so once a release build is installed the file cannot even be read.

So before switching keys on a phone that holds real cards: open **Settings →
Back up the wallet** (F3), keep the file somewhere off the phone, and after the
reinstall use **Restore from a backup** — it brings back every card, photo,
note and step. (*Take a copy* is a readable export only; it cannot be
restored.) Builds made with `RECALLOS_ALLOW_DEBUG_SIGNING=true` stay
debug-signed even once `key.properties` exists, so device checks never trip
this by accident; the phone moves to the Play-signed app once, on purpose. A debug
build still installs over a debug-signed release build, so this can be done
after the fact only if the current install is debug-signed — pull the installed
APK with `adb shell pm path com.recallos.recallos` and check it with
`apksigner verify --print-certs`. (On an *installed APK* apksigner is the right
tool; it is only the bundletool-generated one that lies.)

### Target API level

New apps must target **API 36** (Android 16) as of 31 August 2026. This project
inherits `targetSdk` from the Flutter SDK, so it currently meets that — but a
Flutter version pinned behind the annual bump would fail the upload with a
message naming the required level. Check the merged manifest if that happens:

```bash
grep targetSdkVersion build/app/intermediates/merged_manifest/release/*/AndroidManifest.xml
```

### 16 KB memory pages

From **1 February 2027** Play refuses updates whose native libraries are not
aligned to 16 KB pages. SQLCipher, ML Kit and Flutter's engine all ship `.so`
files. Check the universal APK before each upload:

```bash
zipalign -c -P 16 -v 4 /tmp/recallos-universal.apk | grep -v 'OK'
```

Any line that is not `OK` names a library to update.

---

## Rules that apply as 499B features land

Each of these is triggered by a specific feature in [`PLAN.md`](PLAN.md). Check
the row before the feature ships, not after a rejection.

| When this lands | What Play requires |
|---|---|
| **Any purchase** (Lifetime, Pro) | Play Billing only — no link, button or web view to bKash or a web checkout; Bangladesh has no alternative-billing programme. Billing Library **8 or later** (Flutter: `in_app_purchase_android` 0.5.0+). The merchant profile above must exist first. **RecallOS Plus (A7):** create a one-time product with the ID `recallos_plus` — permanent, it can never be changed or reused — and paste the app's licence key (Monetize with Play → Monetization setup → Licensing) into `lib/features/plus/data/play_key.dart`. Until the key is there the app offers no purchase at all; `release_surface_test.dart` checks a pasted key parses. Add licence testers (Setup → License testing) so test purchases are never charged |
| **A subscription** | The real price and billing period on the paywall — not only a monthly equivalent of an annual price; a trial's length and the price after it; a way to cancel; value that continues (a subscription for a one-time unlock is a violation) |
| **Reminders** | Never declare `USE_EXACT_ALARM` — it is for alarm-clock and calendar apps. Schedule inexactly. Ask for `POST_NOTIFICATIONS` when the first reminder is set, not at launch |
| **IDs** | Treat as sensitive: encrypted photos first, generic lock-screen text, `FLAG_SECURE` on their screens, redaction before sharing |
| **`INTERNET` comes back** (accounts, cloud backup) | In the **same release**: update Data safety (the account email and purchase status are collected; genuinely end-to-end-encrypted content is not), rewrite the privacy policy, show a prominent disclosure with **Agree / Not now** before the first upload of anyone's contact details, and declare ML Kit's own telemetry per Google's ML Kit data-disclosure page. Update `release_surface_test.dart` deliberately — it asserts `INTERNET` is removed |
| **Accounts** | Account deletion inside the app **and** on a public web page that names the app as the listing does; delete everything Data safety declares. App access needs a reusable reviewer login in English with no one-time code |
| **AI-generated text** (e.g. drafted follow-ups) | An in-app way to report offensive output without leaving the app. Ask RecallOS as planned is deterministic and cites stored facts, so this does not apply to it |
| **Importing from the phone's contacts** | Use the Android Contact Picker. Declaring `READ_CONTACTS` while targeting API 37+ needs a Play declaration from **27 January 2027** |
| **Photos from the gallery** | Keep using the picker. `READ_MEDIA_*` stay removed in the manifest |

### The benchmark build is never uploaded

OCR is measured on a release-optimised APK built with
`--dart-define=RECALLOS_BENCH=true`, which compiles the evaluation screen back
in. That APK is for measurement only. The bundle uploaded to Play is always
built **without** the define; CI and `release_surface_test.dart` check that it
defaults to off.

### Dates to keep in view

| Date | What |
|---|---|
| 27 Oct 2026 | Play's pre-review checks start flagging likely violations before submission |
| 27 Jan 2027 | Contacts permission policy for apps targeting API 37+ |
| 1 Feb 2027 | 16 KB page alignment required for updates |
| 2027 | Developer verification enforced worldwide for sideloaded apps |
