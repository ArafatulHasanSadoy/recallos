import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/backup/backup_format.dart';
import 'package:recallos/core/backup/backup_reader.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/theme/app_theme.dart';
import 'package:recallos/features/settings/data/app_info.dart';
import 'package:recallos/features/settings/data/backup_service.dart';
import 'package:recallos/features/settings/presentation/backup_rows.dart';

/// Settings → Back up / Restore, driven by taps.
///
/// The cryptography and the swap are tested in `test/core/`; these check what
/// a person can and cannot do from the screen — above all, that nothing is
/// ever restored without the preview being shown and "Replace" chosen.
void main() {
  late _FakeService service;

  setUp(() => service = _FakeService());

  Future<void> pump(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backupServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Column(children: <Widget>[row])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(int i) => find.byType(TextField).at(i);

  group('backing up', () {
    testWidgets('a short passphrase is refused with a reason, not a dead button', (
      WidgetTester tester,
    ) async {
      await pump(tester, const BackupRow());
      await tester.tap(find.text('Back up the wallet'));
      await tester.pumpAndSettle();

      await tester.enterText(field(0), 'short');
      await tester.enterText(field(1), 'short');
      await tester.tap(find.text('Create backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at least $kMinPassphraseLength'), findsOneWidget);
      expect(service.created, isEmpty);
    });

    testWidgets('two different passphrases are refused', (WidgetTester tester) async {
      await pump(tester, const BackupRow());
      await tester.tap(find.text('Back up the wallet'));
      await tester.pumpAndSettle();

      await tester.enterText(field(0), 'my long passphrase');
      await tester.enterText(field(1), 'my long passphrasf');
      await tester.tap(find.text('Create backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('do not match'), findsOneWidget);
      expect(service.created, isEmpty);
    });

    testWidgets('a good passphrase makes the backup and hands it over', (
      WidgetTester tester,
    ) async {
      await pump(tester, const BackupRow());
      await tester.tap(find.text('Back up the wallet'));
      await tester.pumpAndSettle();

      await tester.enterText(field(0), 'my long passphrase');
      await tester.enterText(field(1), 'my long passphrase');
      await tester.tap(find.text('Create backup'));
      await tester.pumpAndSettle();

      expect(service.created, <String>['my long passphrase']);
      expect(service.shared, 1);
      expect(find.textContaining('Backed up at'), findsOneWidget);
    });
  });

  group('restoring', () {
    Future<void> openWith(WidgetTester tester, String passphrase) async {
      await tester.enterText(field(0), passphrase);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong passphrase asks again instead of giving up', (
      WidgetTester tester,
    ) async {
      await pump(tester, const RestoreRow());
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();

      await openWith(tester, 'wrong one');
      expect(find.text('Open the backup'), findsOneWidget);
      expect(find.textContaining('does not open this backup'), findsOneWidget);

      await openWith(tester, 'the right one');
      expect(find.text('Replace this wallet?'), findsOneWidget);
    });

    testWidgets('the preview says what is in it and what will be lost', (
      WidgetTester tester,
    ) async {
      await pump(tester, const RestoreRow());
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await openWith(tester, 'the right one');

      expect(find.textContaining('12 cards'), findsOneWidget);
      expect(find.textContaining('4 cards here now'), findsOneWidget);
      expect(find.textContaining('will be gone'), findsOneWidget);
    });

    testWidgets('keeping the wallet restores nothing', (WidgetTester tester) async {
      await pump(tester, const RestoreRow());
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await openWith(tester, 'the right one');

      await tester.tap(find.text('Keep this wallet'));
      await tester.pumpAndSettle();

      expect(service.staged, 0);
      expect(find.textContaining('Nothing was changed'), findsOneWidget);
    });

    testWidgets('replacing stages the backup and restarts', (WidgetTester tester) async {
      await pump(tester, const RestoreRow());
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await openWith(tester, 'the right one');

      await tester.tap(find.text('Replace with this backup'));
      await tester.pumpAndSettle();

      expect(service.staged, 1);
    });

    testWidgets('a file that is not a backup says so and changes nothing', (
      WidgetTester tester,
    ) async {
      service.problem = BackupProblem.notABackup;
      await pump(tester, const RestoreRow());
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();
      await openWith(tester, 'anything');

      expect(find.textContaining('not a RecallOS backup'), findsOneWidget);
      expect(service.staged, 0);
    });
  });
}

class _FakeService implements BackupService {
  final List<String> created = <String>[];
  int shared = 0;
  int staged = 0;
  BackupProblem? problem;

  @override
  Future<CreatedBackup> create(String passphrase) async {
    created.add(passphrase);
    return CreatedBackup(file: File('/tmp/x.recallos'), manifest: _manifest);
  }

  @override
  Future<void> share(CreatedBackup backup) async => shared++;

  @override
  Future<String?> pickBackup() async => '/tmp/x.recallos';

  @override
  Future<OpenedBackup> open(String path, String passphrase) async {
    final BackupProblem? p = problem;
    if (p != null) throw BackupException(p);
    if (passphrase != 'the right one') {
      throw const BackupException(BackupProblem.wrongPassphraseOrDamaged);
    }
    return OpenedBackup(
      manifest: _manifest,
      contentKey: Uint8List(32),
      headerBytes: Uint8List(0),
    );
  }

  @override
  Future<int> liveCards() async => 4;

  @override
  Future<bool> stageAndRestart(String path, OpenedBackup opened) async {
    staged++;
    return true;
  }

  @override
  AppDatabase get db => throw UnimplementedError();

  @override
  AppInfo get appInfo => throw UnimplementedError();
}

final BackupManifest _manifest = BackupManifest(
  archiveId: 'a',
  createdAt: DateTime.utc(2026, 9, 29),
  appVersion: '1.0.0 (1) · test',
  schemaVersion: 9,
  counts: const <String, int>{'cards': 12, 'people': 9, 'organizations': 3},
  dataSha256: '',
  dataSize: 0,
  assets: const <BackupAsset>[],
  missingFiles: 0,
);
