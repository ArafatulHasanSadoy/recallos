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

`android/app/build.gradle.kts` reads this file. If it is missing, the release
build falls back to the debug key so `flutter run --release` still works on a
fresh clone — which is safe only because Play rejects a debug certificate
outright, so a fallback build cannot be uploaded by mistake.

> **Back up `recallos-upload.jks` and both passwords somewhere that is not this
> laptop.** Losing them locks you out of updating your own app. Play App Signing
> (accept it when Console offers it) lets Google reset the *upload* key if that
> happens, which is a safety net, not a substitute.

### 2. The privacy policy — yours

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
flutter build appbundle --release
```

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

# Permissions. Expect exactly: CAMERA, USE_BIOMETRIC, USE_FINGERPRINT,
# com.google.android.apps.aicore.service.BIND_SERVICE, and the app's own
# DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
# There must be NO INTERNET and NO RECORD_AUDIO.
aapt dump permissions /tmp/recallos-universal.apk

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
| Target audience | 18+ — keeps the app clear of the Families policy |
| News app | No |
| Government / financial / health | No to all three |
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
| Feature graphic | 1024×500, JPEG or 24-bit PNG, no alpha | to make; `design/BRAND.md` has the material |
| Phone screenshots | 2–8, each side 320–3840 px | `adb exec-out screencap -p > shot.png` on the RMX3612 (1080×2408). Crop to 1080×1920 for Play's 9:16 featuring eligibility |
| Short description | ≤80 characters | to write |
| Full description | ≤4000 characters | to write |

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
Take a copy**, which writes one archive with the contacts, the notes, the
provenance and the photographs, and share it somewhere off the phone. A debug
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
