import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// A database's shape, as plain data that two databases can be compared on.
///
/// The point of comparing a migrated database with a freshly created one: a
/// migration that "worked" but left a column without its default, a missing
/// index or a lost cascade passes every query test and is wrong anyway. This
/// looks at what SQLite itself reports, not at what the Dart code declares.
///
/// Columns are compared by name, not position: `ALTER TABLE ADD COLUMN`
/// appends at the end, where a fresh `CREATE TABLE` puts them in declared
/// order, and that difference is harmless.
Future<Map<String, Object?>> describeSchema(DatabaseConnectionUser db) async {
  Future<List<QueryRow>> q(String sql) => db.customSelect(sql).get();

  final Set<String> shadow = <String>{
    for (final QueryRow r in await q(
      "SELECT name FROM pragma_table_list WHERE schema = 'main' "
      "AND type = 'shadow'",
    ))
      r.read<String>('name'),
  };

  final Map<String, Object?> tables = <String, Object?>{};
  for (final QueryRow t in await q(
    "SELECT name, type FROM pragma_table_list WHERE schema = 'main' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  )) {
    final String name = t.read<String>('name');
    if (shadow.contains(name)) continue;

    if (t.read<String>('type') == 'virtual') {
      final String sql = (await q(
        "SELECT sql FROM sqlite_master WHERE name = '$name'",
      )).single.read<String>('sql');
      tables[name] = <String, Object?>{'virtual': _squash(sql)};
      continue;
    }

    final List<String> columns = <String>[
      for (final QueryRow c in await q('PRAGMA table_info("$name")'))
        '${c.read<String>('name')} ${c.read<String>('type')} '
            'notnull=${c.read<int>('notnull')} '
            'default=${c.read<String?>('dflt_value')} '
            'pk=${c.read<int>('pk')}',
    ]..sort();
    final List<String> foreignKeys = <String>[
      for (final QueryRow f in await q('PRAGMA foreign_key_list("$name")'))
        '${f.read<String>('from')} -> ${f.read<String>('table')}.'
            '${f.read<String?>('to')} on delete ${f.read<String>('on_delete')}',
    ]..sort();
    final List<String> unique = <String>[];
    for (final QueryRow i in await q('PRAGMA index_list("$name")')) {
      if (i.read<int>('unique') != 1) continue;
      final List<String> cols = <String>[
        for (final QueryRow c in await q(
          'PRAGMA index_info("${i.read<String>('name')}")',
        ))
          c.read<String>('name'),
      ];
      unique.add('${i.read<String>('origin')}: ${cols.join(', ')}');
    }
    unique.sort();

    tables[name] = <String, Object?>{
      'columns': columns,
      'foreign_keys': foreignKeys,
      'unique': unique,
    };
  }

  final Map<String, String> indexes = <String, String>{
    for (final QueryRow i in await q(
      "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
      'AND sql IS NOT NULL ORDER BY name',
    ))
      i.read<String>('name'): _squash(i.read<String>('sql')),
  };

  return <String, Object?>{'tables': tables, 'indexes': indexes};
}

/// Fails, naming the first difference, unless [actual] has the same shape as
/// [expected].
Future<void> expectSameSchema(
  DatabaseConnectionUser actual,
  DatabaseConnectionUser expected,
) async {
  expect(await describeSchema(actual), equals(await describeSchema(expected)));
}

/// A database file in [dir] holding exactly the frozen schema of [version]
/// (`test/fixtures/schema_v<version>.sql`), with no rows and `user_version`
/// set — what a phone that last ran that version has on disk. Opening an
/// `AppDatabase` on it runs the real upgrade.
File frozenDatabase(Directory dir, int version) {
  final File file = File(p.join(dir.path, 'recallos_v$version.sqlite'));
  final sqlite.Database raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute(File('test/fixtures/schema_v$version.sql').readAsStringSync());
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.close();
  }
  return file;
}

String _squash(String sql) =>
    sql.replaceAll(RegExp(r'\s+'), ' ').replaceAll('( ', '(').trim();
