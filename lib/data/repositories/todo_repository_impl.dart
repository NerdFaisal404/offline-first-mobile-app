import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';
import '../../domain/entities/vector_clock.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/firebase_datasource.dart';
import '../../core/utils/conflict_resolver.dart';

class TodoRepositoryImpl implements TodoRepository {
  final LocalDatabase _localDatabase;
  final FirebaseDataSource _firebaseDataSource;
  final ConflictResolver _conflictResolver;
  final Uuid _uuid = const Uuid();

  // Stream controllers for real-time updates
  final _todosController = StreamController<List<Todo>>.broadcast();
  final _conflictsController = StreamController<List<Conflict>>.broadcast();

  TodoRepositoryImpl({
    required LocalDatabase localDatabase,
    required FirebaseDataSource firebaseDataSource,
    required ConflictResolver conflictResolver,
  })  : _localDatabase = localDatabase,
        _firebaseDataSource = firebaseDataSource,
        _conflictResolver = conflictResolver;

  @override
  Future<List<Todo>> getAllTodos() async {
    return await _localDatabase.getAllTodos();
  }

  @override
  Future<List<Todo>> getActiveTodos() async {
    return await _localDatabase.getActiveTodos();
  }

  @override
  Future<Todo?> getTodoById(String id) async {
    return await _localDatabase.getTodoById(id);
  }

  @override
  Future<void> createTodo(Todo todo) async {
    await _localDatabase.insertTodo(todo);
    _emitTodosUpdate();
  }

  @override
  Future<void> updateTodo(Todo todo) async {
    await _localDatabase.updateTodo(todo);
    _emitTodosUpdate();
  }

  @override
  Future<void> deleteTodo(String id) async {
    final deviceId = await getCurrentDeviceId();
    final existingTodo = await _localDatabase.getTodoById(id);

    if (existingTodo != null) {
      final deletedTodo = existingTodo.markDeleted(deviceId);
      await _localDatabase.updateTodo(deletedTodo);
    }

    _emitTodosUpdate();
  }

  @override
  Future<List<Conflict>> getUnresolvedConflicts() async {
    return await _localDatabase.getUnresolvedConflicts();
  }

  @override
  Future<void> createConflict(Conflict conflict) async {
    await _localDatabase.insertConflict(conflict);
    _emitConflictsUpdate();
  }

  @override
  Future<void> resolveConflict(Conflict conflict) async {
    await _localDatabase.updateConflict(conflict);
    _emitConflictsUpdate();
  }

  @override
  Future<void> deleteConflict(String conflictId) async {
    await _localDatabase.deleteConflict(conflictId);
    _emitConflictsUpdate();
  }

  @override
  Future<List<Todo>> getTodosNeedingSync() async {
    return await _localDatabase.getTodosNeedingSync();
  }

  @override
  Future<void> markTodoSynced(String id, String? syncId) async {
    await _localDatabase.markTodoSynced(id, syncId);
  }

  @override
  Future<void> syncFromRemote(List<Todo> remoteTodos) async {
    final localTodos = await getAllTodos();
    final deviceId = await getCurrentDeviceId();

    // Process each remote todo
    for (final remoteTodo in remoteTodos) {
      await _processRemoteTodo(remoteTodo, localTodos, deviceId);
    }

    _emitTodosUpdate();
    _emitConflictsUpdate();
  }

  /// Process a single remote todo and handle conflicts
  Future<void> _processRemoteTodo(
    Todo remoteTodo,
    List<Todo> localTodos,
    String deviceId,
  ) async {
    final localTodo =
        localTodos.where((todo) => todo.id == remoteTodo.id).firstOrNull;

    if (localTodo == null) {
      // New remote todo - just insert it
      await _localDatabase
          .insertTodo(remoteTodo.copyWith(syncId: remoteTodo.syncId));
      return;
    }

    // Check for conflicts
    final conflictResolution = _conflictResolver.resolveConflict(
      localVersion: localTodo,
      remoteVersion: remoteTodo,
      currentDeviceId: deviceId,
    );

    switch (conflictResolution.type) {
      case ResolutionType.useLocal:
        // Local version wins - no action needed
        break;

      case ResolutionType.useRemote:
        // Remote version wins - update local
        await _localDatabase.updateTodo(
          remoteTodo.copyWith(syncId: remoteTodo.syncId),
        );
        break;

      case ResolutionType.useAutoMerged:
        // Auto-merged version - update local
        if (conflictResolution.mergedTodo != null) {
          await _localDatabase.updateTodo(conflictResolution.mergedTodo!);
        }
        break;

      case ResolutionType.requiresManualResolution:
        // Create conflict for user resolution
        final conflict = Conflict.create(
          id: _uuid.v4(),
          conflictingTodos: [localTodo, remoteTodo],
        );
        await _localDatabase.insertConflict(conflict);
        break;
    }
  }

  @override
  Future<String> getCurrentDeviceId() async {
    final deviceId = await _localDatabase.getCurrentDeviceId();
    if (deviceId != null) return deviceId;

    // Generate new device ID if none exists
    final newDeviceId = _uuid.v4();
    await updateCurrentDevice(
        newDeviceId, 'Device-${newDeviceId.substring(0, 8)}');
    return newDeviceId;
  }

  @override
  Future<void> updateCurrentDevice(String deviceId, String deviceName) async {
    await _localDatabase.updateCurrentDevice(deviceId, deviceName);
  }

  @override
  Stream<List<Todo>> watchTodos() {
    // Emit initial data
    getAllTodos().then((todos) => _todosController.add(todos));
    return _todosController.stream;
  }

  @override
  Stream<List<Conflict>> watchConflicts() {
    // Emit initial data
    getUnresolvedConflicts()
        .then((conflicts) => _conflictsController.add(conflicts));
    return _conflictsController.stream;
  }

  Future<void> _emitTodosUpdate() async {
    final todos = await getAllTodos();
    _todosController.add(todos);
  }

  Future<void> _emitConflictsUpdate() async {
    final conflicts = await getUnresolvedConflicts();
    _conflictsController.add(conflicts);
  }

  void dispose() {
    _todosController.close();
    _conflictsController.close();
  }
}
