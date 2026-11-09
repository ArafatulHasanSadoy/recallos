import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recallos/core/imaging/photo_vault.dart';
import 'package:recallos/features/capture/data/paper_import.dart';

/// A file somebody chose: checked by what is in it, and turned into a picture
/// capture can read as it reads a scan.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('import_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File file(String name, List<int> bytes) =>
      File(p.join(dir.path, name))..writeAsBytesSync(bytes);

  const List<int> pdf = <int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
  const List<int> jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];
  const List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  PaperImporter importer({PdfFirstPage? render}) => PaperImporter(
    render: render ?? (String _, String _) async => 1,
    scratch: dir,
  );

  test('a JPG and a PNG go straight through', () async {
    for (final (String name, List<int> bytes) in <(String, List<int>)>[
      ('a.jpg', jpeg),
      ('a.png', png),
    ]) {
      final File f = file(name, bytes);
      final ImportOutcome o = await importer().prepare(f);
      expect((o as ImportReady).paper.file.path, f.path);
      expect(o.paper.pages, 1);
    }
  });

  test('a PDF is drawn to a picture the launch sweep would clear', () async {
    final File f = file('bill.pdf', pdf);
    late String drawnTo;
    final ImportOutcome o = await importer(
      render: (String from, String to) async {
        expect(from, f.path);
        drawnTo = to;
        return 3;
      },
    ).prepare(f);

    final ImportedPaper paper = (o as ImportReady).paper;
    expect(paper.file.path, drawnTo);
    expect(paper.pages, 3);
    expect(p.basename(drawnTo), startsWith(kPlainTempPrefix));
    expect(f.existsSync(), isFalse, reason: 'its plain copy is not kept');
  });

  test('judged by what is in it, not by what it is called', () async {
    final File f = file('invoice.pdf', 'MZ not a pdf at all'.codeUnits);
    final ImportOutcome o = await importer(
      render: (String _, String _) async => fail('must not be opened'),
    ).prepare(f);
    expect((o as ImportRefused).reason, contains('PDF, a JPG or a PNG'));
    expect(f.existsSync(), isFalse);
  });

  test('a password-protected PDF says what to do', () async {
    final ImportOutcome o = await importer(
      render: (String _, String _) async =>
          throw const PdfRenderFailed(PdfFailure.locked),
    ).prepare(file('locked.pdf', pdf));
    expect((o as ImportRefused).reason, contains('password'));
  });

  test('a damaged PDF is refused in words', () async {
    final ImportOutcome o = await importer(
      render: (String _, String _) async =>
          throw const PdfRenderFailed(PdfFailure.unreadable),
    ).prepare(file('bad.pdf', pdf));
    expect((o as ImportRefused).reason, contains('damaged'));
  });

  test('over the limit is refused before it is opened', () async {
    final File f = File(p.join(dir.path, 'big.pdf'));
    final RandomAccessFile open = f.openSync(mode: FileMode.write);
    open
      ..writeFromSync(pdf)
      ..truncateSync(kMaxImportBytes + 1)
      ..closeSync();
    final ImportOutcome o = await importer(
      render: (String _, String _) async => fail('must not be opened'),
    ).prepare(f);
    expect((o as ImportRefused).reason, contains('25 MB'));
  });

  test('a file that vanished is refused, not thrown', () async {
    final ImportOutcome o = await importer().prepare(
      File(p.join(dir.path, 'gone.pdf')),
    );
    expect(o, isA<ImportRefused>());
  });
}
