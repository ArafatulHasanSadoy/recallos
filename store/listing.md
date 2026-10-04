# RecallOS — Google Play store listing

Everything Play Console asks for under **Grow users → Store presence → Main store
listing**, ready to paste, plus the assets in this folder. Drafted 2026-10-04.
No prices here: the price is set in Play Console, and pricing stays in the
gitignored `business/` folder.

## Text

**App name** (30/30) — the console currently says *RecallOS*; this
adds what the app is, which helps people searching Play find it:

```
RecallOS: Business Card Wallet
```

**Short description** (74/80):

```
Scan business cards, note why they mattered, find people by what you need.
```

**Full description** (2302/4000):

```
RecallOS is a business-card wallet that remembers why you kept each card.

Meet someone at a fest, an expo or a client's office, scan their card, and add a line about why it mattered — "printed our fest T-shirts", "venue and sound system". Weeks later, search for what you need, not a name you have forgotten, and RecallOS finds them.

FIND PEOPLE BY THE NEED
• Search in your own words. Your notes come first, then everything printed on the card.
• Every result says why it matched, so you can trust it.

SCAN, CHECK, CORRECT
• Photograph the front and the back. Text is read on your phone — names, titles, companies, numbers, emails, websites and addresses, including Bangladeshi phone formats.
• Every value shows whether it was printed on the card or guessed, and a tap shows where on the card it was read.
• Correct anything, any time.

FOLLOW UP
• Add the next step for a card, with a due day and an optional reminder.
• Today shows what is overdue, due today and coming up.
• Note where and when you met.
• Mark a step done — and bring it back if you change your mind.

SAY HELLO
• RecallOS drafts a short first message from your card and where you met. You change what you like and send it yourself in WhatsApp, SMS or email.

YOUR OWN CARD
• Make your card once, then hand it over as a QR code any phone camera can save, or send it as a contact file. You choose which lines go on it.

PEOPLE, NOT JUST CARDS
• Cards from the same person are grouped, and possible duplicates are shown for you to decide — nothing is merged behind your back, and every merge can be undone.
• Call, WhatsApp, email or open the address in maps with one tap.

PRIVATE BY DESIGN
• Everything stays on your phone. RecallOS has no account and no server, and it is built without Android's internet permission, so it cannot send your contacts anywhere.
• Card details and photos are encrypted on the phone.
• An optional fingerprint or PIN lock.
• Encrypted backup to a file you keep, which restores on any phone.
• Deleted cards wait 30 days in Recently deleted before they are gone.

RECALLOS PLUS
The free version keeps up to 5 reminders waiting at a time. RecallOS Plus is a one-time purchase that removes the limit. Scanning, search, notes, next steps, Say hello, your QR card, backup and the lock are always free.
```

Every claim above was checked against the build: Bangladeshi phone formats,
the read-from highlight, people grouping with undoable merges, encrypted
backup, the 30-day Recently deleted, no `INTERNET` permission. Keep it that
way — if a feature changes, change this text in the same release. The
plan's *Honest wording* rule applies: no "never miss", no "100% accurate",
no "AI".

## Graphics

| Asset | File | Play's rule |
|---|---|---|
| App icon | `icon-512.png` (from `assets/brand/png/appicon-512-play.png`) | 512×512, 32-bit PNG with alpha ✓ |
| Feature graphic | `feature-graphic.jpg` | 1024×500, JPEG or 24-bit PNG, no alpha ✓ |
| Phone screenshots | `screenshots/01_search.png` … `06_privacy.png` | 2–8; 1080×1920 (9:16) ✓ |

The screenshots are real screens from the RMX3612 (release build, light
mode) with demo cards only — no real person's card is in them. The QR and
Say hello shots show the owner's own card (*Arafat · EnationX*, a sample
number); swap them if that should not be public.

Remade by: screen captures with `adb exec-out screencap -p`, cropped with
`sips`, laid out as HTML with the bundled Archivo and Instrument Serif, and
rendered at exact size by headless Chrome.

## App content (Policy → App content)

The answers and the reasoning are in `docs/RELEASE.md` → *The App content
declarations* and *Data safety*. In short: no ads; full access without login;
18+ target audience; not a news, government, health or financial app;
**Data safety: no data collected or shared**, because nothing leaves the
phone.

**One to check while filling Data safety:** RecallOS Plus is bought through
Google Play Billing. The app itself sends nothing — the Play Store app handles
the purchase — so the answer should stay *no data collected*; read the form's
help text on in-app purchases before submitting, and answer what it says.

## Category and contact

- **Category:** Business (alternative: Productivity).
- **Contact email:** the one on the payments profile and in the privacy policy.
- **Privacy policy:** https://arafatulhasansadoy.github.io/recallos/privacy-policy.html
