// `isNull`/`isNotNull` are exported by both drift and matcher; the matcher
// ones are meant.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/features/capture/data/card_repository.dart';

/// The two queues that make a bad scan recoverable rather than lost.
///
/// Both exist because a card in trouble is invisible in the library: a failed
/// scan renders the same as a good one, and a soft-deleted card renders not at
/// all. Neither problem announces itself.
void main() {
  late AppDatabase db;
  late CardRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CardRepository(db);
  });
  tearDown(() async => db.close());

  int seq = 0;

  Future<int> card({
    required ExtractionStatus status,
    DateTime? capturedAt,
    DateTime? deletedAt,
  }) async {
    final int id = await db.into(db.cards).insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/card_${++seq}.jpg',
            capturedAt: capturedAt ?? DateTime(2026, 8, seq),
            extractionStatus: Value<ExtractionStatus>(status),
            deletedAt: Value<DateTime?>(deletedAt),
          ),
        );
    return id;
  }

  group('needs attention', () {
    test('collects only the scans that went badly', () async {
      await card(status: ExtractionStatus.complete);
      final int failed = await card(status: ExtractionStatus.failed);
      final int partial = await card(status: ExtractionStatus.partial);
      await card(status: ExtractionStatus.manual);

      final List<CardSummary> queue = await repo.watchNeedsAttention().first;

      expect(
        queue.map((CardSummary c) => c.id),
        unorderedEquals(<int>[failed, partial]),
      );
    });

    test('puts the oldest first', () async {
      final int recent = await card(
        status: ExtractionStatus.failed,
        capturedAt: DateTime(2026, 8, 20),
      );
      final int forgotten = await card(
        status: ExtractionStatus.failed,
        capturedAt: DateTime(2026, 7, 1),
      );

      final List<CardSummary> queue = await repo.watchNeedsAttention().first;

      // A queue that buries the oldest failure defeats its own purpose.
      expect(queue.first.id, forgotten);
      expect(queue.last.id, recent);
    });

    test('a deleted failure is not in the queue', () async {
      await card(
        status: ExtractionStatus.failed,
        deletedAt: DateTime(2026, 8, 22),
      );

      expect(await repo.watchNeedsAttention().first, isEmpty);
    });
  });

  group('recently deleted', () {
    test('finds cards whose undo window never closed', () async {
      // The shape left behind when the app dies inside the five seconds:
      // soft-deleted, never purged, and invisible everywhere.
      final int stranded = await card(
        status: ExtractionStatus.complete,
        deletedAt: DateTime(2026, 8, 22, 4, 3),
      );
      await card(status: ExtractionStatus.complete);

      final List<CardSummary> bin = await repo.watchDeleted().first;

      expect(bin.map((CardSummary c) => c.id), <int>[stranded]);
    });

    test('restoring puts one back in the library', () async {
      final int id = await card(
        status: ExtractionStatus.complete,
        deletedAt: DateTime(2026, 8, 22),
      );
      expect(await repo.watchCards().first, isEmpty);

      await repo.restore(id);

      expect((await repo.watchCards().first).map((CardSummary c) => c.id),
          <int>[id]);
      expect(await repo.watchDeleted().first, isEmpty);
    });
  });
}
