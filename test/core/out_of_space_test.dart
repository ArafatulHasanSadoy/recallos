import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/imaging/photo_keyring.dart';
import 'package:recallos/core/storage/out_of_space.dart';
import 'package:recallos/features/capture/data/card_repository.dart';
import 'package:recallos/features/followup/data/follow_up_repository.dart';

/// A full phone is said in words, and no write pretends to have worked.
void main() {
  const FileSystemException fileFull = FileSystemException(
    'Cannot write file',
    '/data/cards/card_1.jpg',
    OSError('No space left on device', 28),
  );

  test('a real full database is recognised, and nothing is saved', () async {
    // SQLite's own limit on a file's size: the same error, from the same
    // place, as a phone with no room, without filling a phone.
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final int cardId = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/cards/x.jpg',
            capturedAt: DateTime(2026, 11, 1),
          ),
        );
    final int pages = (await db.customSelect('PRAGMA page_count').getSingle())
        .read<int>('page_count');
    await db.customStatement('PRAGMA max_page_count = $pages');

    final FollowUpRepository repo = FollowUpRepository(db);
    Object? thrown;
    int saved = 0;
    for (; saved < 20000 && thrown == null; saved++) {
      try {
        await repo.addStep(
          cardId: cardId,
          title: 'Send the proposal $saved',
          dueOn: DateTime(2026, 11, 12),
        );
      } on Object catch (e) {
        thrown = e;
        saved--;
      }
    }

    expect(thrown, isNotNull, reason: 'the limit was never reached');
    expect(isOutOfSpace(thrown!), isTrue, reason: '$thrown');
    expect(
      await db.select(db.importantDates).get(),
      hasLength(saved),
      reason: 'the one that failed is not half there',
    );
  });

  test('a card that could not be saved leaves no photograph behind', () async {
    final Directory documents = await Directory.systemTemp.createTemp('oos');
    addTearDown(() => documents.delete(recursive: true));
    PathProviderPlatform.instance = _Documents(documents.path);
    PhotoKeyring.instance.debugUseKey(null);
    final File scan = File('${documents.path}/scan.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3]);

    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA query_only = ON'); // Every write fails.

    await expectLater(
      CardRepository(db).createPending(scan),
      throwsA(anything),
    );

    final Directory cards = await CardRepository(db).cardsDirectory();
    expect(cards.listSync(), isEmpty);
  });

  test('a file that could not be written is recognised', () {
    expect(isOutOfSpace(fileFull), isTrue);
  });

  test('other failures are not called a full phone', () {
    expect(isOutOfSpace(StateError('no such card')), isFalse);
    expect(
      isOutOfSpace(
        const FileSystemException('x', 'y', OSError('Permission denied', 13)),
      ),
      isFalse,
    );
  });

  test('the words say what happened, without the error code', () {
    expect(
      failureWords(fileFull, 'Could not read the card'),
      kOutOfSpaceNotice,
    );
    expect(kOutOfSpaceNotice, isNot(contains('errno')));
    expect(
      failureWords(StateError('boom'), 'Could not read the card'),
      startsWith('Could not read the card: '),
    );
  });

  testWidgets('a failure nobody caught still reaches the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(),
      ),
    );

    expect(noticeOutOfSpace(StateError('boom')), isFalse);
    await tester.pump();
    expect(find.text(kOutOfSpaceNotice), findsNothing);

    expect(noticeOutOfSpace(fileFull), isTrue);
    await tester.pump();
    expect(find.text(kOutOfSpaceNotice), findsOneWidget);
  });
}

class _Documents extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Documents(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
