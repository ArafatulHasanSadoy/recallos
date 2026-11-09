import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/field_provenance.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/extraction/receipt_extractor.dart' show formatDay;
import '../../../core/linking/purchase_link_rules.dart' show LinkReason;
import '../../../core/storage/hand_offs.dart';
import '../../capture/data/card_repository.dart' show describeCard;
import 'purchase_links.dart';

/// One value as it leaves the phone: its label, what it says, and where it
/// came from in the words the card screen uses ("on the receipt", "you
/// confirmed", "calculated").
class SharedValue {
  const SharedValue({
    required this.label,
    required this.value,
    required this.source,
  });

  final String label;
  final String value;
  final String source;
}

/// One photograph of a paper. [path] is the sealed copy on the phone, or null
/// when the file is gone — then it is listed as missing and not shared.
class SharedPhoto {
  const SharedPhoto({required this.name, required this.path});

  /// The file name it is shared under.
  final String name;
  final String? path;
}

/// A receipt or a warranty, ready to be shown and shared.
class SharedPaper {
  const SharedPaper({
    required this.cardId,
    required this.kind,
    required this.title,
    required this.values,
    required this.photos,
    this.working,
  });

  final int cardId;

  /// "Receipt" or "Warranty".
  final String kind;
  final String title;
  final List<SharedValue> values;
  final List<SharedPhoto> photos;

  /// How a warranty's end is known, when it is: "Calculated from the
  /// receipt's purchase date, 12 Oct 2026, plus 2 years".
  final String? working;
}

/// A paper and the ones confirmed to belong with it (B3): what a warranty
/// claim needs, in one share.
class PurchasePapers {
  const PurchasePapers({required this.papers, this.linkReasons = const []});

  /// The paper it was opened from first, then its confirmed partners.
  final List<SharedPaper> papers;

  /// Why the papers are together, when there is more than one.
  final List<String> linkReasons;

  String get title => papers.first.title;

  /// Every photograph that will be attached.
  List<SharedPhoto> get attachments => <SharedPhoto>[
    for (final SharedPaper paper in papers)
      for (final SharedPhoto photo in paper.photos)
        if (photo.path != null) photo,
  ];

  /// The note that goes with the files: every value with where it came from,
  /// and what the papers are not.
  ///
  /// Plain text, because it travels to whatever app the user picks — an
  /// email, a chat with a service centre.
  String summary({required DateTime sharedOn}) {
    final StringBuffer b = StringBuffer()
      ..writeln('$title — purchase papers')
      ..writeln(
        'Shared from RecallOS on ${formatDay(LocalDate.fromDateTime(sharedOn))}.',
      );
    for (final SharedPaper paper in papers) {
      b
        ..writeln()
        ..writeln('${paper.kind.toUpperCase()} · ${paper.title}');
      for (final SharedValue v in paper.values) {
        b.writeln('${v.label}: ${v.value} (${v.source})');
      }
      final String? working = paper.working;
      // The screen keeps its date and cover whole with no-break spaces; a
      // note pasted into an email has no narrow column to protect.
      if (working != null) {
        b.writeln(
          'How the end is known: ${working.replaceAll('\u00A0', ' ')}.',
        );
      }
      final List<SharedPhoto> attached = <SharedPhoto>[
        for (final SharedPhoto ph in paper.photos)
          if (ph.path != null) ph,
      ];
      final List<SharedPhoto> missing = <SharedPhoto>[
        for (final SharedPhoto ph in paper.photos)
          if (ph.path == null) ph,
      ];
      if (attached.isNotEmpty) {
        b.writeln(
          'Photograph${attached.length == 1 ? '' : 's'}: '
          '${attached.map((SharedPhoto ph) => ph.name).join(', ')}',
        );
      }
      if (missing.isNotEmpty) {
        b.writeln(
          'Not attached (no longer on the phone): '
          '${missing.map((SharedPhoto ph) => ph.name).join(', ')}',
        );
      }
    }
    if (linkReasons.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Kept together because: ${linkReasons.join('; ')}.');
    }
    b
      ..writeln()
      ..writeln(
        '"On the receipt" and "on the warranty" values were read from the '
        'photographs by the phone and can hold reading mistakes; the '
        'photographs attached are the originals. "You confirmed" and "you '
        'typed" are the owner\'s own. "Calculated" values were worked out by '
        'RecallOS from the others. This is a copy of what was saved, not a '
        'statement from the shop or the maker.',
      );
    return b.toString();
  }
}

/// Reads a receipt or warranty, and its confirmed partners, into
/// [PurchasePapers]. Reads only.
class PurchasePapersReader {
  PurchasePapersReader(this._db, this._links, {required this.label});

  final AppDatabase _db;
  final PurchaseLinks _links;

  /// The field's name as the card screen shows it ("Total", "Serial or IMEI").
  final String Function(String key) label;

  /// Null when [cardId] is gone, in the bin, or not a receipt or warranty.
  Future<PurchasePapers?> read(
    int cardId, {
    List<String> Function(CardType type)? order,
  }) async {
    final CardRow? card = await _card(cardId);
    if (card == null || card.deletedAt != null || !_isPurchase(card.type)) {
      return null;
    }
    final List<PurchaseLink> links = (await _links.watchLinks(cardId).first)
        .where((PurchaseLink l) => l.isConfirmed)
        .toList();

    final List<SharedPaper> papers = <SharedPaper>[
      await _paper(card, order),
      for (final PurchaseLink l in links) await _paper(l.other, order),
    ];
    return PurchasePapers(
      papers: papers,
      linkReasons: <String>[
        for (final PurchaseLink l in links)
          for (final LinkReason r in l.reasons) r.describe(),
      ],
    );
  }

  Future<SharedPaper> _paper(
    CardRow card,
    List<String> Function(CardType type)? order,
  ) async {
    final bool warranty = kWarrantyTypes.contains(card.type);
    final String noun = warranty ? 'warranty' : 'receipt';
    final List<CardField> all = await _fields(card.id);
    final String title = describeCard(card, all).title ?? _capital(noun);

    // What the paper says now: nothing superseded or rejected, nothing blank.
    final List<CardField> current = all
        .where(
          (CardField f) =>
              f.validity != FactValidity.superseded &&
              f.review != FactReview.rejected &&
              f.value.trim().isNotEmpty,
        )
        .toList();
    final List<String> keys = (order ?? (_) => const <String>[])(card.type);
    int rank(CardField f) {
      final int i = keys.indexOf(f.fieldKey);
      return i < 0 ? keys.length : i;
    }

    current.sort((CardField a, CardField b) {
      final int byKey = rank(a).compareTo(rank(b));
      return byKey != 0 ? byKey : a.id.compareTo(b.id);
    });

    final String stem = _fileStem('${_capital(noun)} - $title');
    String? present(String? path) =>
        path != null && File(path).existsSync() ? path : null;
    String ext(String path) {
      final String e = p.extension(path);
      return e.isEmpty ? '.jpg' : e;
    }

    final String? back = card.backImagePath;
    final ExpiryView? end = warranty ? await _links.expiry(card.id) : null;

    return SharedPaper(
      cardId: card.id,
      kind: _capital(noun),
      title: title,
      values: <SharedValue>[
        for (final CardField f in current)
          SharedValue(
            label: label(f.fieldKey),
            value: f.value,
            source: describeProvenance(f, paper: noun).$1,
          ),
      ],
      photos: <SharedPhoto>[
        // A paper that was typed in never had one, which is not the same as
        // one that is "no longer on this phone".
        if (card.imagePath.isNotEmpty)
          SharedPhoto(
            name: back == null
                ? '$stem${ext(card.imagePath)}'
                : '$stem - front${ext(card.imagePath)}',
            path: present(card.imagePath),
          ),
        if (back != null)
          SharedPhoto(name: '$stem - back${ext(back)}', path: present(back)),
      ],
      working: end?.expiry.explain(),
    );
  }

  static bool _isPurchase(CardType t) =>
      kReceiptTypes.contains(t) || kWarrantyTypes.contains(t);

  static String _capital(String s) => s[0].toUpperCase() + s.substring(1);

  /// A file name a person will recognise, with nothing a file system or a
  /// mail app would refuse.
  static String _fileStem(String s) {
    final String clean = s
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.length > 60 ? clean.substring(0, 60).trim() : clean;
  }

  Future<CardRow?> _card(int id) => (_db.select(
    _db.cards,
  )..where(($CardsTable c) => c.id.equals(id))).getSingleOrNull();

  Future<List<CardField>> _fields(int cardId) => (_db.select(
    _db.cardFields,
  )..where(($CardFieldsTable f) => f.cardId.equals(cardId))).get();
}

/// What became of a share, so the sheet can say something true.
enum PapersShareResult { shared, failed }

/// Opens the photographs and hands everything to the share sheet.
class PapersShare {
  PapersShare({required this.openPhoto, Future<Directory> Function()? outbox})
    : _outbox = outbox ?? outboxDirectory;

  /// The photograph in the clear, from its sealed copy.
  final Future<Uint8List> Function(String path) openPhoto;
  final Future<Directory> Function() _outbox;

  /// Writes the summary and each photograph into a fresh folder in the
  /// outbox, and returns them. Separate from [share] so a test can open what
  /// would be handed over.
  Future<List<File>> writeFiles(PurchasePapers papers, DateTime now) async {
    final Directory outbox = await _outbox();
    final Directory dir = Directory(
      p.join(outbox.path, 'papers-${now.microsecondsSinceEpoch}'),
    )..createSync(recursive: true);
    final List<File> files = <File>[];
    final File note = File(
      p.join(dir.path, '${PurchasePapersReader._fileStem(papers.title)}.txt'),
    );
    await note.writeAsString(papers.summary(sharedOn: now));
    files.add(note);
    for (final SharedPhoto photo in papers.attachments) {
      final File out = File(p.join(dir.path, photo.name));
      await out.writeAsBytes(await openPhoto(photo.path!));
      files.add(out);
    }
    return files;
  }

  Future<PapersShareResult> share(PurchasePapers papers) async {
    final DateTime now = DateTime.now();
    List<File> files = const <File>[];
    try {
      files = await writeFiles(papers, now);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[for (final File f in files) XFile(f.path)],
          subject: '${papers.title} — purchase papers',
          text: papers.summary(sharedOn: now),
        ),
      );
      return PapersShareResult.shared;
    } on Object {
      return PapersShareResult.failed;
    } finally {
      // Photographs in the clear: not kept a moment longer than the hand-over.
      // share_plus keeps its own copy, which the launch sweep clears after a
      // day (`hand_offs.dart`).
      for (final File f in files) {
        await discardHandOff(f);
      }
      if (files.isNotEmpty) {
        try {
          files.first.parent.deleteSync(recursive: true);
        } on Object {
          // The launch sweep.
        }
      }
    }
  }
}
