import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';
import '../../domain/entities/vector_clock.dart';
import '../datasources/local_database.dart';

/// Firebase datasource for syncing todos, devices, and conflicts with Firestore
class FirebaseDataSource {
  final FirebaseFirestore _firestore;
  static const String _todosCollection = 'todos';
  static const String _devicesCollection = 'devices';
  static const String _conflictsCollection = 'conflicts';

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

  // =============================================================================
  // DEVICE OPERATIONS
  // =============================================================================

  /// Upload device information to Firebase
  Future<void> uploadDevice(DeviceData device) async {
    try {
      await _firestore.collection(_devicesCollection).doc(device.id).set({
        'id': device.id,
        'name': device.name,
        'lastSeen': device.lastSeen.toIso8601String(),
        'isCurrentDevice': device.isCurrentDevice,
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to upload device: $e',
      );
    }
  }

  /// Download all devices from Firebase
  Future<List<DeviceData>> downloadDevices() async {
    try {
      final snapshot = await _firestore.collection(_devicesCollection).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DeviceData(
          id: data['id'],
          name: data['name'],
          lastSeen: DateTime.parse(data['lastSeen']),
          isCurrentDevice: data['isCurrentDevice'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to download devices: $e',
      );
    }
  }

  /// Listen to real-time device changes
  Stream<List<DeviceData>> watchDevices() {
    return _firestore
        .collection(_devicesCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return DeviceData(
          id: data['id'],
          name: data['name'],
          lastSeen: DateTime.parse(data['lastSeen']),
          isCurrentDevice: data['isCurrentDevice'] ?? false,
        );
      }).toList();
    });
  }

  /// Update device last seen timestamp
  Future<void> updateDeviceLastSeen(String deviceId) async {
    try {
      await _firestore.collection(_devicesCollection).doc(deviceId).update({
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to update device last seen: $e',
      );
    }
  }

  // =============================================================================
  // CONFLICT OPERATIONS
  // =============================================================================

  /// Upload conflict to Firebase
  Future<void> uploadConflict(Conflict conflict) async {
    try {
      await _firestore.collection(_conflictsCollection).doc(conflict.id).set({
        'id': conflict.id,
        'todoId': conflict.todoId,
        'versions': conflict.versions
            .map((v) => {
                  'id': v.id,
                  'name': v.name,
                  'price': v.price,
                  'isCompleted': v.isCompleted,
                  'isDeleted': v.isDeleted,
                  'vectorClock': v.vectorClock.toJson(),
                  'deviceId': v.deviceId,
                  'updatedAt': v.updatedAt.toIso8601String(),
                })
            .toList(),
        'detectedAt': conflict.detectedAt.toIso8601String(),
        'type': conflict.type.index,
        'isResolved': conflict.isResolved,
        'resolvedBy': conflict.resolvedBy,
        'resolvedAt': conflict.resolvedAt?.toIso8601String(),
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to upload conflict: $e',
      );
    }
  }

  /// Download conflicts from Firebase
  Future<List<Conflict>> downloadConflicts() async {
    try {
      final snapshot = await _firestore.collection(_conflictsCollection).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _conflictFromFirebaseData(data);
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to download conflicts: $e',
      );
    }
  }

  /// Listen to real-time conflict changes
  Stream<List<Conflict>> watchConflicts() {
    return _firestore
        .collection(_conflictsCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _conflictFromFirebaseData(data);
      }).toList();
    });
  }

  /// Delete a conflict from Firebase
  Future<void> deleteConflict(String conflictId) async {
    try {
      await _firestore
          .collection(_conflictsCollection)
          .doc(conflictId)
          .delete();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Failed to delete conflict: $e',
      );
    }
  }

  /// Helper method to convert Firebase data to Conflict entity
  Conflict _conflictFromFirebaseData(Map<String, dynamic> data) {
    final versionsData = data['versions'] as List<dynamic>;
    final versions = versionsData.map((vData) {
      final versionData = vData as Map<String, dynamic>;
      return ConflictVersion(
        id: versionData['id'],
        name: versionData['name'],
        price: (versionData['price'] as num).toDouble(),
        isCompleted: versionData['isCompleted'],
        isDeleted: versionData['isDeleted'],
        vectorClock: VectorClock.fromJson(versionData['vectorClock']),
        deviceId: versionData['deviceId'],
        updatedAt: DateTime.parse(versionData['updatedAt']),
      );
    }).toList();

    return Conflict(
      id: data['id'],
      todoId: data['todoId'],
      versions: versions,
      detectedAt: DateTime.parse(data['detectedAt']),
      type: ConflictType.values[data['type']],
      isResolved: data['isResolved'],
      resolvedBy: data['resolvedBy'],
      resolvedAt: data['resolvedAt'] != null
          ? DateTime.parse(data['resolvedAt'])
          : null,
    );
  }
}
