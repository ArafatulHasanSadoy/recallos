# Security policy

RecallOS keeps business cards, receipts and warranties on the phone, in an
encrypted database and encrypted photographs, and is built without the
Android `INTERNET` permission. There is no RecallOS server and no account,
so the developer holds no user data. A security problem here is a problem in
the app on the phone, in the files it writes, or in how it hands things to
other apps.

## Reporting a vulnerability

Email **arafatsadoy@gmail.com** with the subject line **"RecallOS
security"**. Please include:

- the version (Settings → About → *Version*; tap it to copy);
- the phone and Android version;
- what an attacker needs (physical access, another app installed, a crafted
  backup file…) and what they get;
- steps to reproduce.

Do **not** attach a real wallet, backup or photograph of anybody's card. If
a file is needed to show the problem, make one with invented data.

Please do not open a public GitHub issue for a vulnerability until a fixed
version is on Google Play.

## What to expect

- An acknowledgement, aimed at within 7 days.
- An assessment: whether it is a vulnerability, how serious, and what is
  affected.
- A fix in a new Play release, rolled out in stages, with the release notes
  saying what was fixed once users have had the chance to update.
- Credit in the release notes if you would like it.

## In scope

- The encrypted database (SQLCipher, key in the Android Keystore) and the
  sealed photographs (`lib/core/imaging/photo_vault.dart`).
- The backup format (`lib/core/backup/`): passphrase handling, tampering,
  path traversal, oversized or truncated files, restore and roll-back.
- Plaintext left behind: caches, scans, exports, shared files
  (`lib/core/storage/hand_offs.dart`).
- The app lock (`LockGate`), deep links, notifications on the lock screen.
- Anything the app hands to another app: vCards, the QR code, shared
  receipts and warranties, the receipt-totals spreadsheet.
- Text read from a photographed paper being treated as anything but data.
- The RecallOS Plus purchase check.
- The permissions the installed app actually has.

## Out of scope

- A phone that is already rooted or compromised.
- What another app does with a file after you chose to share it there.
- Google Play, ML Kit and Android themselves (report those to Google).

## Incident handling

1. Reproduce on the current Play build; write down the version and steps.
2. Decide the severity: can it expose a wallet's contents, change them, or
   lose them?
3. Fix on a branch, with a test that fails before the fix.
4. Ship through the normal release checks (`docs/RELEASE.md`), staged
   rollout, and halt the rollout if the fix misbehaves.
5. Record what happened, what was affected and what changed in the release
   notes, and in `docs/STATUS.md`.

Because nothing is collected, there is no user database to breach and no
list of users to notify; the release notes and the Play listing are how
users hear about a fix.
