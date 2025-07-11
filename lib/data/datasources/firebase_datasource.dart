import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/todo.dart';

/// Firebase datasource for syncing todos with Firestore
class FirebaseDataSource {
  final FirebaseFirestore _firestore;
  static const String _todosCollection = 'todos';

  FirebaseDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Upload local todos to Firebase
  Future<void> uploadTodos(List<Todo> todos) async {
    final batch = _firestore.batch();

    for (final todo in todos) {
      final docRef =
          _firestore.collection(_todosCollection).doc(todo.syncId ?? todo.id);
      batch.set(docRef, todo.toJson());
    }

    await batch.commit();
  }

  /// Download todos from Firebase
  Future<List<Todo>> downloadTodos() async {
    try {
      final snapshot = await _firestore.collection(_todosCollection).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['syncId'] = doc.id; // Store the Firestore document ID
        return Todo.fromJson(data);
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to download todos: $e',
      );
    }
  }

  /// Upload a single todo
  Future<String> uploadTodo(Todo todo) async {
    try {
      final docRef = todo.syncId != null
          ? _firestore.collection(_todosCollection).doc(todo.syncId)
          : _firestore.collection(_todosCollection).doc();

      await docRef.set(todo.toJson());
      return docRef.id;
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to upload todo: $e',
      );
    }
  }

  /// Delete a todo from Firebase
  Future<void> deleteTodo(String syncId) async {
    try {
      await _firestore.collection(_todosCollection).doc(syncId).delete();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to delete todo: $e',
      );
    }
  }

  /// Listen to real-time changes from Firebase
  Stream<List<Todo>> watchTodos() {
    return _firestore.collection(_todosCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['syncId'] = doc.id;
        return Todo.fromJson(data);
      }).toList();
    });
  }

  /// Get todos modified after a specific timestamp
  Future<List<Todo>> getTodosModifiedAfter(DateTime timestamp) async {
    try {
      final snapshot = await _firestore
          .collection(_todosCollection)
          .where('updatedAt', isGreaterThan: timestamp.toIso8601String())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['syncId'] = doc.id;
        return Todo.fromJson(data);
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to get modified todos: $e',
      );
    }
  }

  /// Check if Firebase is available
  Future<bool> isAvailable() async {
    try {
      await _firestore.disableNetwork();
      await _firestore.enableNetwork();
      return true;
    } catch (e) {
      return false;
    }
  }
}
