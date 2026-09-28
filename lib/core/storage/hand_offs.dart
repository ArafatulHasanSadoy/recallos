import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../backup/backup_format.dart';
import '../imaging/photo_vault.dart';

/// Files that pass through the cache on their way somewhere else, and how long
/// each may stay there.
///
/// A photograph is sealed the moment the app owns it, but getting it in, and
/// getting anything back out, goes through files that are not: the scanner's
/// result, the picker's copy, a plain copy for OCR, an export on its way to
/// the share sheet. Android empties a cache only when storage runs low, so
/// "the OS reclaims it" meant never in practice — the first scan on a test
/// phone was still in the scanner's folder, in the clear, the next day, while
/// Settings said the card photographs were encrypted.
///
/// Every kind is declared here with the rule that clears it, so the next one
/// added has one place to go and one test to join
/// (`test/features/retention_sweep_test.dart`).

/// Where ML Kit's document scanner writes what it photographed. The scanner
/// plugin's `cleanCache` removes its own copies and never looks in here.
const String kScannerFolder = 'mlkit_docscan_ui_client';

/// Where share_plus copies anything it hands to another app. It empties the
/// folder at the start of the next share, which may never come.
const String kShareFolder = 'share_plus';

/// Where the app writes the files it hands to another app: exports, backups,
/// vCards.
const String kOutboxFolder = 'outbox';

/// Files only this app reads, for moments: whatever made them deletes them,
/// and a crash in between is cleared after this.
const Duration kPrivateHandOffLife = Duration(minutes: 10);

/// Files handed to another app, which may still be reading them — an email
/// draft holding an attachment, an upload in the background.
const Duration kSharedHandOffLife = Duration(days: 1);

/// The pickers copy what they return into a folder named with a UUID
/// (image_picker's portrait, file_selector's backup).
final RegExp _pickerFolder = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// The cache folder for files the app hands to another app.
Future<Directory> outboxDirectory() async {
  final Directory cache = await getTemporaryDirectory();
  return Directory(p.join(cache.path, kOutboxFolder))
    ..createSync(recursive: true);
}

/// Deletes a hand-off the app has finished with. A failure is left for the
/// launch sweep rather than reported: tidying up is never why an action failed.
Future<void> discardHandOff(File file) async {
  try {
    if (file.existsSync()) await file.delete();
  } on Object {
    // Next launch.
  }
}

/// Deletes what the document scanner left behind, once the picture is sealed
/// in the app's own storage: the plugin's copy, and ML Kit's original.
Future<void> clearScannerLeftovers() async {
  try {
    await CunningDocumentScanner.cleanCache();
  } on Object {
    // The launch sweep asks again.
  }
  try {
    final Directory cache = await getTemporaryDirectory();
    _empty(
      Directory(p.join(cache.path, kScannerFolder)),
      now: DateTime.now(),
      life: Duration.zero,
    );
  } on Object {
    // The launch sweep has it.
  }
}

/// Clears every hand-off under [cache] that has outlived its rule. Returns how
/// many files went. Anything not declared above is left exactly as it is.
int sweepHandOffs(Directory cache, {required DateTime now}) {
  if (!cache.existsSync()) return 0;
  int removed = 0;
  for (final FileSystemEntity entry in cache.listSync()) {
    final String name = p.basename(entry.path);
    if (entry is File) {
      final Duration? life = _looseFileLife(name);
      if (life != null && _delete(entry, now: now, life: life)) removed++;
    } else if (entry is Directory) {
      final Duration? life = _folderLife(name);
      if (life == null) continue;
      removed += _empty(entry, now: now, life: life);
      // A picker's folder exists only to hold its copy; the named folders are
      // left in place for the plugins that expect them.
      if (_pickerFolder.hasMatch(name)) _removeIfEmpty(entry);
    }
  }
  return removed;
}

Duration? _looseFileLife(String name) {
  // OCR's plain copy (and a region crop); image_picker's downscaled copy.
  if (name.startsWith(kPlainTempPrefix) || name.startsWith('scaled_')) {
    return kPrivateHandOffLife;
  }
  // Written to the cache root before the outbox existed.
  if (name.endsWith('.$kBackupExtension') ||
      name.endsWith('.vcf') ||
      (name.startsWith('recallos-') && name.endsWith('.zip'))) {
    return kSharedHandOffLife;
  }
  return null;
}

Duration? _folderLife(String name) => switch (name) {
  kScannerFolder => kPrivateHandOffLife,
  kShareFolder || kOutboxFolder => kSharedHandOffLife,
  _ when _pickerFolder.hasMatch(name) => kPrivateHandOffLife,
  _ => null,
};

/// Deletes every file under [dir] older than [life].
int _empty(Directory dir, {required DateTime now, required Duration life}) {
  if (!dir.existsSync()) return 0;
  int removed = 0;
  for (final FileSystemEntity entry in dir.listSync(recursive: true)) {
    if (entry is File && _delete(entry, now: now, life: life)) removed++;
  }
  return removed;
}

bool _delete(File file, {required DateTime now, required Duration life}) {
  try {
    if (now.difference(file.lastModifiedSync()) < life) return false;
    file.deleteSync();
    return true;
  } on Object {
    // One stubborn file is not a reason to stop clearing the rest.
    return false;
  }
}

void _removeIfEmpty(Directory dir) {
  try {
    for (final FileSystemEntity d in dir.listSync(recursive: true).reversed) {
      if (d is Directory && d.listSync().isEmpty) d.deleteSync();
    }
    if (dir.listSync().isEmpty) dir.deleteSync();
  } on Object {
    // Next launch.
  }
}
