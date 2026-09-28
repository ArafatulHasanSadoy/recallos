import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/storage/hand_offs.dart';
import '../../capture/data/card_repository.dart';
import '../../contacts/data/identity_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Resolved at construction, not through a `Ref`: the sweep runs across many
/// awaits at launch, and a provider read for its side effect is disposed
/// underneath it (see "A service must not hold a Ref across an await" in
/// CLAUDE.md).
final retentionSweepProvider = Provider<RetentionSweep>(
  (Ref ref) => RetentionSweep(
    db: ref.watch(databaseProvider),
    cards: ref.watch(cardRepositoryProvider),
    identity: ref.watch(identityRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
  ),
);

/// Finishes the deletes the user already asked for, and clears files nothing
/// points at.
///
/// Both delete paths in the app are soft, which made them safe and made them
/// permanent: a deleted card and its full-size photographs stayed on the phone
/// forever, and nothing anywhere compared `deleted_at` to a date. Recently
/// deleted now means what it says — thirty days, then gone.
///
/// It destroys only what the user already chose to delete, through the exact
/// two steps "Delete for good" takes, so it can never remove something the
/// user did not ask to lose.
class RetentionSweep {
  RetentionSweep({
    required this.db,
    required this.cards,
    required this.identity,
    required this.profiles,
    this.now = DateTime.now,
    this.temporaryDirectory = getTemporaryDirectory,
    this.cleanScanner = CunningDocumentScanner.cleanCache,
  });

  final AppDatabase db;
  final CardRepository cards;
  final IdentityRepository identity;
  final ProfileRepository profiles;

  /// Injected so a test can stand thirty days in the future.
  final DateTime Function() now;

  /// The cache the hand-offs pass through. Injected for tests.
  final Future<Directory> Function() temporaryDirectory;

  /// Removes the scanner plugin's own copies, which it keeps outside the
  /// cache. Injected for tests.
  final Future<void> Function() cleanScanner;

  /// How long a deleted card waits in Recently deleted. The screen and the
  /// privacy policy both state this number; change all three together.
  static const Duration keepDeletedFor = Duration(days: 30);

  /// An unreferenced portrait younger than this is left alone: the profile
  /// editor writes a picked photo before Save, so a fresh one may belong to an
  /// editor that is open right now.
  static const Duration orphanGrace = Duration(days: 1);

  /// Runs every part. Never throws — a sweep that fails at launch must not take
  /// the launch down with it; whatever it missed, the next launch tries again.
  Future<void> run() async {
    try {
      await purgeExpired();
      await removeOrphanPortraits();
      await removeStaleHandOffs();
    } on Object {
      // Deliberately quiet; see above.
    }
  }

  /// Permanently removes cards deleted more than [keepDeletedFor] ago.
  /// Returns how many went.
  Future<int> purgeExpired() async {
    final DateTime cutoff = now().subtract(keepDeletedFor);
    final List<CardRow> expired =
        await (db.select(db.cards)
              ..where(($CardsTable c) => c.deletedAt.isSmallerThanValue(cutoff)))
            .get();

    for (final CardRow card in expired) {
      // Same order as the "Delete for good" button: unhook the person and
      // company first, then destroy the card and its files.
      await identity.detach(card.id);
      await cards.purge(card.id);
    }
    return expired.length;
  }

  /// Clears the copies that passed through the cache and were never removed:
  /// the scanner's pictures, OCR's plain copies, the pickers' copies, exports
  /// already handed over. The rules, and why they exist, are in
  /// `hand_offs.dart`. Launch is the one moment nothing is using them.
  Future<int> removeStaleHandOffs() async {
    try {
      await cleanScanner();
    } on Object {
      // Not a reason to leave the rest.
    }
    return sweepHandOffs(await temporaryDirectory(), now: now());
  }

  /// Deletes portrait files no profile row points at — including rows that are
  /// soft-deleted, whose photo must survive for a restore.
  ///
  /// These are the leak the profile editor had before it cleaned up after
  /// itself: every replaced, removed or abandoned portrait stayed on disk.
  Future<int> removeOrphanPortraits() async {
    final Directory dir = await profiles.profileDirectory();
    final Set<String> referenced = <String>{
      for (final Profile row in await db.select(db.profiles).get())
        if (row.photoPath case final String path) p.normalize(path),
    };

    int removed = 0;
    for (final FileSystemEntity entry in dir.listSync()) {
      if (entry is! File) continue;
      if (referenced.contains(p.normalize(entry.path))) continue;
      if (now().difference(entry.lastModifiedSync()) < orphanGrace) continue;
      try {
        entry.deleteSync();
        removed++;
      } on Object {
        // One stubborn file is not a reason to stop clearing the rest.
      }
    }
    return removed;
  }
}
