import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../core/services/sync_service.dart';
import 'app_providers.dart';

// Todo operations notifier
class TodoNotifier extends StateNotifier<AsyncValue<void>> {
  final TodoRepository _repository;
  final String _deviceId;
  final Uuid _uuid = const Uuid();

  TodoNotifier(this._repository, this._deviceId)
      : super(const AsyncValue.data(null));

  Future<void> createTodo({
    required String name,
    required double price,
  }) async {
    state = const AsyncValue.loading();

    try {
      final todo = Todo.create(
        id: _uuid.v4(),
        name: name,
        price: price,
        deviceId: _deviceId,
      );

      await _repository.createTodo(todo);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateTodo({
    required String todoId,
    String? name,
    double? price,
    bool? isCompleted,
  }) async {
    state = const AsyncValue.loading();

    try {
      final existingTodo = await _repository.getTodoById(todoId);
      if (existingTodo == null) throw Exception('Todo not found');

      final updatedTodo = existingTodo.updateWith(
        name: name,
        price: price,
        isCompleted: isCompleted,
        updatingDeviceId: _deviceId,
      );

      await _repository.updateTodo(updatedTodo);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteTodo(String todoId) async {
    state = const AsyncValue.loading();

    try {
      await _repository.deleteTodo(todoId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleTodoCompletion(String todoId) async {
    try {
      final existingTodo = await _repository.getTodoById(todoId);
      if (existingTodo == null) return;

      await updateTodo(
        todoId: todoId,
        isCompleted: !existingTodo.isCompleted,
      );
    } catch (e) {
      // Handle error silently for toggle operations
    }
  }
}

// Conflict resolution notifier
class ConflictNotifier extends StateNotifier<AsyncValue<void>> {
  final TodoRepository _repository;
  final String _deviceId;

  ConflictNotifier(this._repository, this._deviceId)
      : super(const AsyncValue.data(null));

  Future<void> resolveConflict({
    required String conflictId,
    required String selectedVersionId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final conflicts = await _repository.getUnresolvedConflicts();
      final conflict = conflicts.where((c) => c.id == conflictId).firstOrNull;

      if (conflict == null) throw Exception('Conflict not found');

      // Find the selected version
      final selectedVersion =
          conflict.versions.where((v) => v.id == selectedVersionId).firstOrNull;

      if (selectedVersion == null)
        throw Exception('Selected version not found');

      // Create todo from selected version
      final resolvedTodo = Todo(
        id: selectedVersion.id,
        name: selectedVersion.name,
        price: selectedVersion.price,
        isCompleted: selectedVersion.isCompleted,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: selectedVersion.vectorClock.increment(_deviceId),
        deviceId: _deviceId,
        version: 1,
        isDeleted: selectedVersion.isDeleted,
      );

      // Update the todo with resolved version
      await _repository.updateTodo(resolvedTodo);

      // Mark conflict as resolved
      final resolvedConflict = conflict.resolve(
        winningVersionId: selectedVersionId,
        resolvingDeviceId: _deviceId,
      );

      await _repository.resolveConflict(resolvedConflict);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> resolveConflictWithMerge({
    required String conflictId,
    required String selectedName,
    required double selectedPrice,
    required bool selectedCompletion,
  }) async {
    state = const AsyncValue.loading();

    try {
      final conflicts = await _repository.getUnresolvedConflicts();
      final conflict = conflicts.where((c) => c.id == conflictId).firstOrNull;

      if (conflict == null) throw Exception('Conflict not found');

      // Create merged version
      final baseVersion = conflict.versions.first;
      final mergedTodo = Todo(
        id: baseVersion.id,
        name: selectedName,
        price: selectedPrice,
        isCompleted: selectedCompletion,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: baseVersion.vectorClock.increment(_deviceId),
        deviceId: _deviceId,
        version: 1,
        isDeleted: baseVersion.isDeleted,
      );

      // Update the todo with merged version
      await _repository.updateTodo(mergedTodo);

      // Mark conflict as resolved
      final resolvedConflict = conflict.resolve(
        winningVersionId: 'merged',
        resolvingDeviceId: _deviceId,
      );

      await _repository.resolveConflict(resolvedConflict);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> dismissConflict(String conflictId) async {
    try {
      await _repository.deleteConflict(conflictId);
    } catch (e) {
      // Handle error
    }
  }
}

// Sync operations notifier
class SyncNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  final SyncService _syncService;

  SyncNotifier(this._syncService) : super(const AsyncValue.data(null));

  Future<void> forcSync() async {
    state = const AsyncValue.loading();

    try {
      final result = await _syncService.forcSync();
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Provider factories
final todoNotifierProvider =
    StateNotifierProvider<TodoNotifier, AsyncValue<void>>((ref) {
  final repository = ref.read(todoRepositoryProvider);
  // Use a default device ID first, will be updated when device ID is ready
  return TodoNotifier(repository, 'temp-device');
});

final conflictNotifierProvider =
    StateNotifierProvider<ConflictNotifier, AsyncValue<void>>((ref) {
  final repository = ref.read(todoRepositoryProvider);
  // Use a default device ID first, will be updated when device ID is ready
  return ConflictNotifier(repository, 'temp-device');
});

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, AsyncValue<SyncResult?>>((ref) {
  final syncService = ref.read(syncServiceProvider);
  return SyncNotifier(syncService);
});

// Device-aware providers that wait for device ID
final deviceAwareTodoNotifierProvider =
    StateNotifierProvider.family<TodoNotifier, AsyncValue<void>, String>(
        (ref, deviceId) {
  final repository = ref.read(todoRepositoryProvider);
  return TodoNotifier(repository, deviceId);
});

final deviceAwareConflictNotifierProvider =
    StateNotifierProvider.family<ConflictNotifier, AsyncValue<void>, String>(
        (ref, deviceId) {
  final repository = ref.read(todoRepositoryProvider);
  return ConflictNotifier(repository, deviceId);
});

// UI state providers
final selectedTodoProvider = StateProvider<Todo?>((ref) => null);
final showConflictsProvider = StateProvider<bool>((ref) => false);
