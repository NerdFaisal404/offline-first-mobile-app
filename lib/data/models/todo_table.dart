import 'package:drift/drift.dart';

/// Drift table for storing todos with conflict resolution metadata
@DataClassName('TodoData')
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Conflict resolution metadata
  TextColumn get vectorClockJson => text().named('vector_clock_json')();
  TextColumn get deviceId => text().named('device_id')();
  IntColumn get version => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable().named('sync_id')();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
