import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/imaging/photo_vault.dart' show kPlainTempPrefix;
import '../../../core/storage/hand_offs.dart' show discardHandOff;
import '../../../core/storage/out_of_space.dart' show appMessengerKey;

/// The largest file RecallOS will take in: well above any bill or warranty,
/// and small enough that opening one cannot run a low-end phone out of memory.
const int kMaxImportBytes = 25 * 1024 * 1024;

/// A picture ready to be read as if it had just been scanned.
class ImportedPaper {
  const ImportedPaper(this.file, {this.pages = 1});

  /// A plain file in the cache. Capture deletes it once it is sealed.
  final File file;

  /// How many pages the document has. Only the first is kept.
  final int pages;
}

/// What became of a file somebody chose.
sealed class ImportOutcome {
  const ImportOutcome();
}

class ImportReady extends ImportOutcome {
  const ImportReady(this.paper);
  final ImportedPaper paper;
}

class ImportRefused extends ImportOutcome {
  const ImportRefused(this.reason);

  /// Said to the user, as it is.
  final String reason;
}

/// Why a PDF could not be drawn.
enum PdfFailure { locked, unreadable }

class PdfRenderFailed implements Exception {
  const PdfRenderFailed(this.failure);
  final PdfFailure failure;
}

/// Draws page one of a PDF into a picture and says how many pages there are.
typedef PdfFirstPage = Future<int> Function(String pdf, String picture);

/// Android's own renderer, over a channel (`MainActivity`).
Future<int> renderPdfFirstPage(String pdf, String picture) async {
  const MethodChannel channel = MethodChannel('recallos/pdf');
  try {
    final int? pages = await channel.invokeMethod<int>(
      'renderFirstPage',
      <String, String>{'path': pdf, 'out': picture},
    );
    return pages ?? 1;
  } on PlatformException catch (e) {
    throw PdfRenderFailed(
      e.code == 'locked' ? PdfFailure.locked : PdfFailure.unreadable,
    );
  }
}

/// Checks a chosen file and makes it into a picture capture can read.
class PaperImporter {
  const PaperImporter({required this.render, required this.scratch});

  final PdfFirstPage render;

  /// Where a drawn page goes. Named so the launch sweep clears it if the app
  /// dies before capture does.
  final Directory scratch;

  static const String _tooBig =
      'That file is over 25 MB, too large to bring in.';
  static const String _wrongKind =
      'RecallOS can bring in a PDF, a JPG or a PNG. That file is something '
      'else.';
  static const String _unreadable =
      'That file could not be opened. It may be damaged.';
  static const String _locked =
      'That PDF has a password. Open it elsewhere, take a screenshot, and '
      'bring that in instead.';

  Future<ImportOutcome> prepare(File picked) async {
    final _Kind? kind;
    try {
      final int size = await picked.length();
      if (size > kMaxImportBytes) {
        await discardHandOff(picked);
        return const ImportRefused(_tooBig);
      }
      kind = _kindOf(await _head(picked));
    } on FileSystemException {
      return const ImportRefused(_unreadable);
    }
    switch (kind) {
      case null:
        // Judged by what is in the file, not what it is called: a renamed
        // file must not reach the readers.
        await discardHandOff(picked);
        return const ImportRefused(_wrongKind);
      case _Kind.picture:
        return ImportReady(ImportedPaper(picked));
      case _Kind.pdf:
        final String out = p.join(
          scratch.path,
          '${kPlainTempPrefix}pdf_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        try {
          final int pages = await render(picked.path, out);
          return ImportReady(ImportedPaper(File(out), pages: pages));
        } on PdfRenderFailed catch (e) {
          return ImportRefused(switch (e.failure) {
            PdfFailure.locked => _locked,
            PdfFailure.unreadable => _unreadable,
          });
        } finally {
          await discardHandOff(picked);
        }
    }
  }

  static Future<Uint8List> _head(File f) async {
    final RandomAccessFile open = await f.open();
    try {
      return await open.read(8);
    } finally {
      await open.close();
    }
  }

  static _Kind? _kindOf(Uint8List h) {
    bool starts(List<int> magic) {
      if (h.length < magic.length) return false;
      for (int i = 0; i < magic.length; i++) {
        if (h[i] != magic[i]) return false;
      }
      return true;
    }

    if (starts(const <int>[0x25, 0x50, 0x44, 0x46])) return _Kind.pdf;
    if (starts(const <int>[0xFF, 0xD8, 0xFF])) return _Kind.picture;
    if (starts(const <int>[0x89, 0x50, 0x4E, 0x47])) return _Kind.picture;
    return null;
  }
}

enum _Kind { pdf, picture }

/// The system picker. No storage permission: it grants this one file.
Future<File?> pickPaperFile() async {
  final XFile? file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[
      XTypeGroup(
        label: 'PDF or picture',
        extensions: <String>['pdf', 'jpg', 'jpeg', 'png'],
        mimeTypes: <String>['application/pdf', 'image/jpeg', 'image/png'],
      ),
    ],
  );
  return file == null ? null : File(file.path);
}

final Provider<Future<File?> Function()> pickPaperFileProvider =
    Provider<Future<File?> Function()>((_) => pickPaperFile);

final Provider<Future<PaperImporter> Function()> paperImporterProvider =
    Provider<Future<PaperImporter> Function()>(
      (_) =>
          () async => PaperImporter(
            render: renderPdfFirstPage,
            scratch: await getTemporaryDirectory(),
          ),
    );

/// Says that a longer document was cut to its first page, as it happens.
void noticeFirstPageOnly(int pages) {
  appMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text('Kept page 1 of $pages. Only one page is saved.')),
  );
}
