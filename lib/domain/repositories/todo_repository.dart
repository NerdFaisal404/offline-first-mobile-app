import '../entities/todo.dart';
import '../entities/conflict.dart';

/// Abstract repository for todo operations
abstract class TodoRepository {
  // Basic CRUD operations
  Future<List<Todo>> getAllTodos();
  Future<List<Todo>> getActiveTodos();
  Future<Todo?> getTodoById(String id);
  Future<void> createTodo(Todo todo);
  Future<void> updateTodo(Todo todo);
  Future<void> deleteTodo(String id);

  // Conflict resolution operations
  Future<List<Conflict>> getUnresolvedConflicts();
  Future<void> createConflict(Conflict conflict);
  Future<void> resolveConflict(Conflict conflict);
  Future<void> deleteConflict(String conflictId);

  // Sync operations
  Future<List<Todo>> getTodosNeedingSync();
  Future<void> markTodoSynced(String id, String? syncId);
  Future<void> syncFromRemote(List<Todo> remoteTodos);

  // Device management
  Future<String> getCurrentDeviceId();
  Future<void> updateCurrentDevice(String deviceId, String deviceName);

  // Stream for real-time updates
  Stream<List<Todo>> watchTodos();
  Stream<List<Conflict>> watchConflicts();
}
