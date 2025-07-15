import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/todo_table.dart';
import '../models/conflict_table.dart';
import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';
import '../../domain/entities/vector_clock.dart';

part 'local_database.g.dart';

@DriftDatabase(tables: [Todos, Conflicts, Devices])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Todo operations
  Future<List<Todo>> getAllTodos() async {
    final todoData = await select(todos).get();
    return todoData.map((data) => _todoDataToEntity(data)).toList();
  }

  Future<List<Todo>> getActiveTodos() async {
    final todoData =
        await (select(todos)..where((t) => t.isDeleted.equals(false))).get();
    return todoData.map((data) => _todoDataToEntity(data)).toList();
  }

  Future<Todo?> getTodoById(String id) async {
    final todoDataList =
        await (select(todos)..where((t) => t.id.equals(id))).get();

    if (todoDataList.isEmpty) return null;

    if (todoDataList.length > 1) {
      // Handle duplicates - keep the most recent one and delete others
      print(
          '⚠️ Found ${todoDataList.length} todos with same ID: $id - cleaning up duplicates');

      // Sort by updatedAt, keep the latest
      todoDataList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final latestTodo = todoDataList.first;

      // Delete all duplicates and re-insert the latest one
      await (delete(todos)..where((t) => t.id.equals(id))).go();
      await into(todos)
          .insert(_todoEntityToData(_todoDataToEntity(latestTodo)));

      return _todoDataToEntity(latestTodo);
    }

    return _todoDataToEntity(todoDataList.first);
  }

  Future<List<Todo>> getTodosNeedingSync() async {
    final todoData =
        await (select(todos)..where((t) => t.needsSync.equals(true))).get();
    return todoData.map((data) => _todoDataToEntity(data)).toList();
  }

  Future<void> insertTodo(Todo todo) async {
    await into(todos).insert(_todoEntityToData(todo));
  }

  Future<void> updateTodo(Todo todo) async {
    await update(todos).replace(_todoEntityToData(todo));
  }

  Future<void> deleteTodo(String id) async {
    await (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markTodoSynced(String id, String? syncId) async {
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        syncId: Value(syncId),
        needsSync: const Value(false),
      ),
    );
  }

  // Conflict operations
  Future<List<Conflict>> getAllConflicts() async {
    final conflictData = await select(conflicts).get();
    return conflictData.map((data) => _conflictDataToEntity(data)).toList();
  }

  Future<List<Conflict>> getUnresolvedConflicts() async {
    final conflictData = await (select(conflicts)
          ..where((c) => c.isResolved.equals(false)))
        .get();
    return conflictData.map((data) => _conflictDataToEntity(data)).toList();
  }

  Future<void> insertConflict(Conflict conflict) async {
    await into(conflicts).insert(_conflictEntityToData(conflict));
  }

  Future<void> updateConflict(Conflict conflict) async {
    await update(conflicts).replace(_conflictEntityToData(conflict));
  }

  Future<void> deleteConflict(String id) async {
    await (delete(conflicts)..where((c) => c.id.equals(id))).go();
  }

  // Device operations
  Future<void> updateCurrentDevice(String deviceId, String deviceName) async {
    // First, mark all devices as not current
    await update(devices).write(const DevicesCompanion(
      isCurrentDevice: Value(false),
    ));

    // Then update or insert the current device
    await into(devices).insertOnConflictUpdate(
      DevicesCompanion.insert(
        id: deviceId,
        name: deviceName,
        lastSeen: DateTime.now(),
        isCurrentDevice: Value(true),
      ),
    );
  }

  Future<String?> getCurrentDeviceId() async {
    final deviceList = await (select(devices)
          ..where((d) => d.isCurrentDevice.equals(true)))
        .get();

    if (deviceList.isEmpty) return null;

    if (deviceList.length > 1) {
      // Multiple current devices - clean up and keep the most recent
      print(
          '⚠️ Found ${deviceList.length} current devices - cleaning up duplicates');

      // Sort by lastSeen, keep the latest
      deviceList.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      final latestDevice = deviceList.first;

      // Mark all as not current, then set the latest one as current
      await update(devices)
          .write(DevicesCompanion(isCurrentDevice: Value(false)));
      await (update(devices)..where((d) => d.id.equals(latestDevice.id)))
          .write(DevicesCompanion(isCurrentDevice: Value(true)));

      return latestDevice.id;
    }

    return deviceList.first.id;
  }

  // Utility methods for entity conversion
  Todo _todoDataToEntity(TodoData data) {
    return Todo(
      id: data.id,
      name: data.name,
      price: data.price,
      isCompleted: data.isCompleted,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      vectorClock: VectorClock.fromJson(
        jsonDecode(data.vectorClockJson) as Map<String, dynamic>,
      ),
      deviceId: data.deviceId,
      version: data.version,
      isDeleted: data.isDeleted,
      syncId: data.syncId,
    );
  }

  TodosCompanion _todoEntityToData(Todo todo) {
    return TodosCompanion.insert(
      id: todo.id,
      name: todo.name,
      price: todo.price,
      isCompleted: Value(todo.isCompleted),
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt,
      vectorClockJson: jsonEncode(todo.vectorClock.toJson()),
      deviceId: todo.deviceId,
      version: todo.version,
      isDeleted: Value(todo.isDeleted),
      syncId: Value(todo.syncId),
      needsSync: Value(true),
    );
  }

  Conflict _conflictDataToEntity(ConflictData data) {
    final versionsJson = jsonDecode(data.versionsJson) as List<dynamic>;
    final versions = versionsJson
        .map((json) => _conflictVersionFromJson(json as Map<String, dynamic>))
        .toList();

    return Conflict(
      id: data.id,
      todoId: data.todoId,
      versions: versions,
      detectedAt: data.detectedAt,
      type: ConflictType.values[data.conflictType],
      isResolved: data.isResolved,
      resolvedBy: data.resolvedBy,
      resolvedAt: data.resolvedAt,
    );
  }

  ConflictsCompanion _conflictEntityToData(Conflict conflict) {
    final versionsJson = conflict.versions
        .map((version) => _conflictVersionToJson(version))
        .toList();

    return ConflictsCompanion.insert(
      id: conflict.id,
      todoId: conflict.todoId,
      versionsJson: jsonEncode(versionsJson),
      detectedAt: conflict.detectedAt,
      conflictType: conflict.type.index,
      isResolved: Value(conflict.isResolved),
      resolvedBy: Value(conflict.resolvedBy),
      resolvedAt: Value(conflict.resolvedAt),
    );
  }

  ConflictVersion _conflictVersionFromJson(Map<String, dynamic> json) {
    return ConflictVersion(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      isCompleted: json['isCompleted'],
      isDeleted: json['isDeleted'],
      vectorClock: VectorClock.fromJson(json['vectorClock']),
      deviceId: json['deviceId'],
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> _conflictVersionToJson(ConflictVersion version) {
    return {
      'id': version.id,
      'name': version.name,
      'price': version.price,
      'isCompleted': version.isCompleted,
      'isDeleted': version.isDeleted,
      'vectorClock': version.vectorClock.toJson(),
      'deviceId': version.deviceId,
      'updatedAt': version.updatedAt.toIso8601String(),
    };
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'offline_todo.db'));
    return NativeDatabase(file);
  });
}
