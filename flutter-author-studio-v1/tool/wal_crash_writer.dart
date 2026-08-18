import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Expected database path and ready-marker path.');
    exit(2);
  }

  final database = sqlite3.open(arguments[0]);
  database.execute('PRAGMA journal_mode = WAL');
  database.execute('PRAGMA synchronous = FULL');
  database.execute('PRAGMA foreign_keys = ON');
  database.execute('BEGIN IMMEDIATE');
  database.execute('''
    INSERT INTO connected_entities (id, kind, scope_id)
    VALUES ('uncommitted-crash-row', 'record', 'probe-project')
  ''');
  File(arguments[1]).writeAsStringSync('ready', flush: true);

  await Completer<void>().future;
}
