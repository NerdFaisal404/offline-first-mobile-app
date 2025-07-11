import 'package:drift/drift.dart';

/// Drift table for storing conflicts
@DataClassName('ConflictData')
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text().named('todo_id')();
  TextColumn get versionsJson =>
      text().named('versions_json')(); // JSON array of conflict versions
  DateTimeColumn get detectedAt => dateTime().named('detected_at')();
  IntColumn get conflictType =>
      integer().named('conflict_type')(); // ConflictType enum index
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  TextColumn get resolvedBy =>
      text().nullable().named('resolved_by')(); // Device ID
  DateTimeColumn get resolvedAt => dateTime().nullable().named('resolved_at')();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for storing device information
@DataClassName('DeviceData')
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get lastSeen => dateTime().named('last_seen')();
  BoolColumn get isCurrentDevice =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
