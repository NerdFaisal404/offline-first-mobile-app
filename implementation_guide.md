# Advanced Implementation Guide: Offline Sync System

This document provides detailed implementation instructions and advanced topics for the offline sync system tutorial.

## Table of Contents

1. [Database Schema Setup](#database-schema-setup)
2. [Firebase Configuration](#firebase-configuration)
3. [State Management with Riverpod](#state-management-with-riverpod)
4. [Advanced Conflict Resolution](#advanced-conflict-resolution)
5. [Performance Optimizations](#performance-optimizations)
6. [Testing Strategies](#testing-strategies)
7. [Deployment Considerations](#deployment-considerations)

## Database Schema Setup

### Local SQLite Database with Drift

```dart
// lib/data/datasources/local_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_database.g.dart';

@DataClassName('TodoTableData')
class TodoTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get vectorClockJson => text()();
  TextColumn get deviceId => text()();
  IntColumn get version => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ConflictTableData')  
class ConflictTable extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text()();
  TextColumn get versionsJson => text()();
  DateTimeColumn get detectedAt => dateTime()();
  IntColumn get conflictType => integer()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TodoTable, ConflictTable])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Todo operations
  Future<List<Todo>> getAllTodos() async {
    final rows = await select(todoTable).get();
    return rows.map(_todoFromRow).toList();
  }

  Future<List<Todo>> getActiveTodos() async {
    final rows = await (select(todoTable)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    return rows.map(_todoFromRow).toList();
  }

  Future<Todo?> getTodoById(String id) async {
    final row = await (select(todoTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _todoFromRow(row) : null;
  }

  Future<List<Todo>> getTodosNeedingSync() async {
    final rows = await (select(todoTable)
          ..where((t) => t.needsSync.equals(true)))
        .get();
    return rows.map(_todoFromRow).toList();
  }

  Future<void> insertTodo(Todo todo) async {
    await into(todoTable).insert(_todoToRow(todo));
  }

  Future<void> updateTodo(Todo todo) async {
    await update(todoTable).replace(_todoToRow(todo));
  }

  Future<void> markAsSynced(String todoId) async {
    await (update(todoTable)..where((t) => t.id.equals(todoId)))
        .write(const TodoTableCompanion(needsSync: Value(false)));
  }

  // Conflict operations
  Future<List<Conflict>> getUnresolvedConflicts() async {
    final rows = await (select(conflictTable)
          ..where((c) => c.isResolved.equals(false)))
        .get();
    return rows.map(_conflictFromRow).toList();
  }

  Future<void> insertConflict(Conflict conflict) async {
    await into(conflictTable).insert(_conflictToRow(conflict));
  }

  Future<void> updateConflict(Conflict conflict) async {
    await update(conflictTable).replace(_conflictToRow(conflict));
  }

  // Helper methods for conversion
  Todo _todoFromRow(TodoTableData row) {
    return Todo(
      id: row.id,
      name: row.name,
      price: row.price,
      isCompleted: row.isCompleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      vectorClock: VectorClock.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.vectorClockJson)),
      ),
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      syncId: row.syncId,
    );
  }

  TodoTableData _todoToRow(Todo todo) {
    return TodoTableData(
      id: todo.id,
      name: todo.name,
      price: todo.price,
      isCompleted: todo.isCompleted,
      createdAt: todo.createdAt,
      updatedAt: todo.updatedAt,
      vectorClockJson: jsonEncode(todo.vectorClock.toJson()),
      deviceId: todo.deviceId,
      version: todo.version,
      isDeleted: todo.isDeleted,
      syncId: todo.syncId,
      needsSync: true,
    );
  }

  Conflict _conflictFromRow(ConflictTableData row) {
    final versionsJson = jsonDecode(row.versionsJson) as List;
    final versions = versionsJson
        .map((v) => Todo.fromJson(Map<String, dynamic>.from(v)))
        .toList();

    return Conflict(
      id: row.id,
      todoId: row.todoId,
      versions: versions,
      detectedAt: row.detectedAt,
      type: ConflictType.values[row.conflictType],
      isResolved: row.isResolved,
    );
  }

  ConflictTableData _conflictToRow(Conflict conflict) {
    return ConflictTableData(
      id: conflict.id,
      todoId: conflict.todoId,
      versionsJson: jsonEncode(
        conflict.versions.map((v) => v.toJson()).toList(),
      ),
      detectedAt: conflict.detectedAt,
      conflictType: conflict.type.index,
      isResolved: conflict.isResolved,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'todos.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

### Firebase Firestore Integration

```dart
// lib/data/datasources/firebase_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';

class FirebaseDataSource {
  final FirebaseFirestore _firestore;
  final String _todosCollection = 'todos';
  final String _conflictsCollection = 'conflicts';
  final String _devicesCollection = 'devices';

  FirebaseDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Todo operations
  Future<void> saveTodo(Todo todo) async {
    final docRef = _firestore.collection(_todosCollection).doc(todo.id);
    await docRef.set(todo.toJson(), SetOptions(merge: true));
  }

  Future<List<Todo>> getAllTodos() async {
    final snapshot = await _firestore.collection(_todosCollection).get();
    return snapshot.docs
        .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<Todo?> getTodoById(String id) async {
    final doc = await _firestore.collection(_todosCollection).doc(id).get();
    if (!doc.exists) return null;
    return Todo.fromJson({...doc.data()!, 'id': doc.id});
  }

  Future<void> deleteTodo(String id) async {
    await _firestore.collection(_todosCollection).doc(id).delete();
  }

  // Real-time streams
  Stream<List<Todo>> watchTodos() {
    return _firestore
        .collection(_todosCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Todo.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Conflict>> watchConflicts() {
    return _firestore
        .collection(_conflictsCollection)
        .where('isResolved', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conflict.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Device management
  Future<void> updateDeviceHeartbeat(String deviceId) async {
    await _firestore.collection(_devicesCollection).doc(deviceId).set({
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  Stream<List<DeviceInfo>> watchDevices() {
    return _firestore
        .collection(_devicesCollection)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeviceInfo.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Conflict operations
  Future<void> saveConflict(Conflict conflict) async {
    await _firestore
        .collection(_conflictsCollection)
        .doc(conflict.id)
        .set(conflict.toJson());
  }

  Future<void> resolveConflict(String conflictId) async {
    await _firestore
        .collection(_conflictsCollection)
        .doc(conflictId)
        .update({'isResolved': true});
  }

  // Batch operations for better performance
  Future<void> batchSaveTodos(List<Todo> todos) async {
    final batch = _firestore.batch();
    
    for (final todo in todos) {
      final docRef = _firestore.collection(_todosCollection).doc(todo.id);
      batch.set(docRef, todo.toJson(), SetOptions(merge: true));
    }
    
    await batch.commit();
  }
}
```

## State Management with Riverpod

```dart
// lib/presentation/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Core dependencies
final uuidProvider = Provider((ref) => const Uuid());

final deviceIdProvider = FutureProvider<String>((ref) async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    }
  } catch (e) {
    print('Error getting device ID: $e');
  }
  return 'unknown-device-${DateTime.now().millisecondsSinceEpoch}';
});

// Database providers
final localDatabaseProvider = Provider((ref) => LocalDatabase());

final firebaseDataSourceProvider = Provider((ref) => FirebaseDataSource());

final conflictResolverProvider = Provider((ref) => ConflictResolver());

// Repository providers
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final localDb = ref.read(localDatabaseProvider);
  final firebaseDs = ref.read(firebaseDataSourceProvider);
  final conflictResolver = ref.read(conflictResolverProvider);
  
  return TodoRepositoryImpl(
    localDatabase: localDb,
    firebaseDataSource: firebaseDs,
    conflictResolver: conflictResolver,
  );
});

// Sync service provider
final syncServiceProvider = Provider((ref) {
  final todoRepository = ref.read(todoRepositoryProvider);
  final firebaseDataSource = ref.read(firebaseDataSourceProvider);
  final localDatabase = ref.read(localDatabaseProvider);
  
  return SyncService(
    todoRepository: todoRepository,
    firebaseDataSource: firebaseDataSource,
    localDatabase: localDatabase,
  );
});

// Sync status provider
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final syncService = ref.read(syncServiceProvider);
  final todoRepository = ref.read(todoRepositoryProvider);
  
  // Combine multiple streams to create sync status
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    final todos = await todoRepository.getAllTodos();
    final conflicts = await todoRepository.getUnresolvedConflicts();
    final pendingUploads = todos.where((t) => t.needsSync).length;
    
    yield SyncStatus(
      isConnected: await syncService.isConnected(),
      isSyncing: syncService.isSyncing,
      pendingUploads: pendingUploads,
      unresolvedConflicts: conflicts.length,
      lastSyncAt: syncService.lastSyncAt,
    );
  }
});

// UI state providers
final showConflictsProvider = StateProvider<bool>((ref) => false);

final selectedConflictProvider = StateProvider<String?>((ref) => null);
```

```dart
// lib/presentation/providers/todo_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Todos stream provider
final todosProvider = StreamProvider<List<Todo>>((ref) async* {
  final repository = ref.read(todoRepositoryProvider);
  
  // Initial load
  yield await repository.getActiveTodos();
  
  // Listen for changes
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    yield await repository.getActiveTodos();
  }
});

// Conflicts stream provider
final conflictsProvider = StreamProvider<List<Conflict>>((ref) async* {
  final repository = ref.read(todoRepositoryProvider);
  
  // Initial load
  yield await repository.getUnresolvedConflicts();
  
  // Listen for changes
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    yield await repository.getUnresolvedConflicts();
  }
});

// Todo operations provider
final todoOperationsProvider = Provider((ref) => TodoOperations(ref));

class TodoOperations {
  final Ref _ref;
  
  TodoOperations(this._ref);
  
  Future<void> createTodo({
    required String name,
    required double price,
  }) async {
    final repository = _ref.read(todoRepositoryProvider);
    final deviceId = await _ref.read(deviceIdProvider.future);
    final uuid = _ref.read(uuidProvider);
    
    final todo = Todo.create(
      id: uuid.v4(),
      name: name,
      price: price,
      deviceId: deviceId,
    );
    
    await repository.createTodo(todo);
  }
  
  Future<void> updateTodo({
    required String id,
    String? name,
    double? price,
    bool? isCompleted,
  }) async {
    final repository = _ref.read(todoRepositoryProvider);
    final deviceId = await _ref.read(deviceIdProvider.future);
    
    final existingTodo = await repository.getTodoById(id);
    if (existingTodo == null) return;
    
    final updatedTodo = existingTodo.updateWith(
      name: name,
      price: price,
      isCompleted: isCompleted,
      updatingDeviceId: deviceId,
    );
    
    await repository.updateTodo(updatedTodo);
  }
  
  Future<void> deleteTodo(String id) async {
    final repository = _ref.read(todoRepositoryProvider);
    await repository.deleteTodo(id);
  }
  
  Future<void> resolveConflictWithVersion(String conflictId, Todo version) async {
    final repository = _ref.read(todoRepositoryProvider);
    final deviceId = await _ref.read(deviceIdProvider.future);
    
    // Update the todo with the selected version
    final resolvedTodo = version.copyWith(
      vectorClock: version.vectorClock.increment(deviceId),
      deviceId: deviceId,
      version: version.version + 1,
      updatedAt: DateTime.now(),
    );
    
    await repository.updateTodo(resolvedTodo);
    
    // Mark conflict as resolved
    final conflict = await repository.getConflictById(conflictId);
    if (conflict != null) {
      await repository.resolveConflict(
        conflict.copyWith(isResolved: true),
      );
    }
  }
  
  Future<void> autoResolveConflict(String conflictId) async {
    final repository = _ref.read(todoRepositoryProvider);
    final conflictResolver = _ref.read(conflictResolverProvider);
    final deviceId = await _ref.read(deviceIdProvider.future);
    
    final conflict = await repository.getConflictById(conflictId);
    if (conflict == null || conflict.versions.length < 2) return;
    
    final resolution = conflictResolver.resolveConflict(
      localVersion: conflict.versions[0],
      remoteVersion: conflict.versions[1],
      currentDeviceId: deviceId,
    );
    
    if (resolution.mergedTodo != null) {
      await repository.updateTodo(resolution.mergedTodo!);
      await repository.resolveConflict(
        conflict.copyWith(isResolved: true),
      );
    }
  }
}
```

## Advanced Conflict Resolution

### Custom Merge Strategies

```dart
// lib/core/utils/advanced_conflict_resolver.dart
class AdvancedConflictResolver extends ConflictResolver {
  
  @override
  ConflictResolution _resolveConcurrentConflict(
    Todo localVersion,
    Todo remoteVersion,
    String currentDeviceId,
  ) {
    // Use machine learning or heuristics for smart merging
    final mergeStrategy = _determineBestMergeStrategy(localVersion, remoteVersion);
    
    switch (mergeStrategy) {
      case MergeStrategy.semanticMerge:
        return _performSemanticMerge(localVersion, remoteVersion, currentDeviceId);
      case MergeStrategy.userPreferenceMerge:
        return _performUserPreferenceMerge(localVersion, remoteVersion, currentDeviceId);
      case MergeStrategy.contextualMerge:
        return _performContextualMerge(localVersion, remoteVersion, currentDeviceId);
      default:
        return super._resolveConcurrentConflict(localVersion, remoteVersion, currentDeviceId);
    }
  }
  
  MergeStrategy _determineBestMergeStrategy(Todo local, Todo remote) {
    // Analyze the changes to determine the best merge strategy
    final localChanges = _analyzeChanges(local);
    final remoteChanges = _analyzeChanges(remote);
    
    if (_isSemanticallySimilar(local.name, remote.name)) {
      return MergeStrategy.semanticMerge;
    }
    
    if (_hasUserPreferencePattern(localChanges, remoteChanges)) {
      return MergeStrategy.userPreferenceMerge;
    }
    
    return MergeStrategy.contextualMerge;
  }
  
  ConflictResolution _performSemanticMerge(Todo local, Todo remote, String deviceId) {
    // Example: Merge similar names intelligently
    String mergedName;
    if (local.name.contains(remote.name) || remote.name.contains(local.name)) {
      // Choose the longer, more descriptive name
      mergedName = local.name.length > remote.name.length ? local.name : remote.name;
    } else {
      // Combine both names intelligently
      mergedName = "${local.name} / ${remote.name}";
    }
    
    // Choose higher price (assuming price increases are more common)
    final mergedPrice = local.price > remote.price ? local.price : remote.price;
    
    final mergedTodo = local.copyWith(
      name: mergedName,
      price: mergedPrice,
      vectorClock: local.vectorClock.merge(remote.vectorClock).increment(deviceId),
      deviceId: deviceId,
      version: local.version + 1,
      updatedAt: DateTime.now(),
    );
    
    return ConflictResolution(
      type: ResolutionType.useAutoMerged,
      mergedTodo: mergedTodo,
    );
  }
  
  ConflictResolution _performUserPreferenceMerge(Todo local, Todo remote, String deviceId) {
    // Use historical user preferences to guide merging
    final userPreferences = _getUserPreferences(deviceId);
    
    final mergedName = userPreferences.preferDescriptiveNames 
        ? (local.name.length > remote.name.length ? local.name : remote.name)
        : local.name; // Prefer local if no clear preference
        
    final mergedPrice = userPreferences.preferHigherPrices
        ? (local.price > remote.price ? local.price : remote.price)
        : (local.price < remote.price ? local.price : remote.price);
    
    final mergedTodo = local.copyWith(
      name: mergedName,
      price: mergedPrice,
      vectorClock: local.vectorClock.merge(remote.vectorClock).increment(deviceId),
      deviceId: deviceId,
      version: local.version + 1,
      updatedAt: DateTime.now(),
    );
    
    return ConflictResolution(
      type: ResolutionType.useAutoMerged,
      mergedTodo: mergedTodo,
    );
  }
  
  bool _isSemanticallySimilar(String name1, String name2) {
    // Implement semantic similarity checking
    // This could use fuzzy string matching, NLP, etc.
    final similarity = _calculateLevenshteinSimilarity(name1, name2);
    return similarity > 0.7; // 70% similarity threshold
  }
  
  double _calculateLevenshteinSimilarity(String s1, String s2) {
    // Implementation of Levenshtein distance for string similarity
    // Returns a value between 0 and 1, where 1 is identical
    final matrix = List.generate(s1.length + 1, 
        (i) => List.generate(s2.length + 1, (j) => 0));
    
    for (int i = 0; i <= s1.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= s2.length; j++) matrix[0][j] = j;
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    return 1.0 - (matrix[s1.length][s2.length] / maxLength);
  }
}

enum MergeStrategy {
  semanticMerge,
  userPreferenceMerge,  
  contextualMerge,
  manualMerge,
}

class UserPreferences {
  final bool preferDescriptiveNames;
  final bool preferHigherPrices;
  final bool preferCompletedState;
  
  const UserPreferences({
    this.preferDescriptiveNames = true,
    this.preferHigherPrices = false,
    this.preferCompletedState = true,
  });
}
```

### Operational Transform

For more sophisticated real-time collaboration:

```dart
// lib/core/utils/operational_transform.dart
class OperationalTransform {
  
  /// Transform an operation against another operation
  static Operation transform(Operation op1, Operation op2) {
    if (op1.type == OperationType.insert && op2.type == OperationType.insert) {
      return _transformInsertInsert(op1, op2);
    } else if (op1.type == OperationType.delete && op2.type == OperationType.delete) {
      return _transformDeleteDelete(op1, op2);
    } else if (op1.type == OperationType.insert && op2.type == OperationType.delete) {
      return _transformInsertDelete(op1, op2);
    } else if (op1.type == OperationType.delete && op2.type == OperationType.insert) {
      return _transformDeleteInsert(op1, op2);
    }
    
    return op1; // No transformation needed
  }
  
  static Operation _transformInsertInsert(Operation op1, Operation op2) {
    if (op1.position <= op2.position) {
      return op1;
    } else {
      return op1.copyWith(position: op1.position + op2.content.length);
    }
  }
  
  static Operation _transformDeleteDelete(Operation op1, Operation op2) {
    if (op1.position + op1.length <= op2.position) {
      return op1;
    } else if (op2.position + op2.length <= op1.position) {
      return op1.copyWith(position: op1.position - op2.length);
    } else {
      // Overlapping deletes - complex case
      return _handleOverlappingDeletes(op1, op2);
    }
  }
  
  // Additional transform methods...
}

class Operation {
  final OperationType type;
  final int position;
  final String content;
  final int length;
  final String field; // 'name', 'price', etc.
  
  const Operation({
    required this.type,
    required this.position,
    required this.content,
    required this.length,
    required this.field,
  });
  
  Operation copyWith({
    OperationType? type,
    int? position,
    String? content,
    int? length,
    String? field,
  }) {
    return Operation(
      type: type ?? this.type,
      position: position ?? this.position,
      content: content ?? this.content,
      length: length ?? this.length,
      field: field ?? this.field,
    );
  }
}

enum OperationType { insert, delete, retain }
```

## Performance Optimizations

### Batching and Compression

```dart
// lib/core/services/optimized_sync_service.dart
class OptimizedSyncService extends SyncService {
  
  static const int _maxBatchSize = 50;
  static const Duration _batchWindow = Duration(seconds: 5);
  
  final List<Todo> _pendingUploads = [];
  Timer? _batchTimer;
  
  @override
  Future<UploadResult> _uploadLocalChanges() async {
    final todosNeedingSync = await _todoRepository.getTodosNeedingSync();
    
    if (todosNeedingSync.isEmpty) {
      return UploadResult(count: 0);
    }
    
    // Compress data before upload
    final compressedTodos = await _compressTodos(todosNeedingSync);
    
    // Upload in batches
    int uploadedCount = 0;
    for (int i = 0; i < todosNeedingSync.length; i += _maxBatchSize) {
      final batch = todosNeedingSync.skip(i).take(_maxBatchSize).toList();
      await _firebaseDataSource.batchSaveTodos(batch);
      
      // Mark as synced
      for (final todo in batch) {
        await _todoRepository.markAsSynced(todo.id);
      }
      
      uploadedCount += batch.length;
      
      // Add delay between batches to avoid overwhelming the network
      if (i + _maxBatchSize < todosNeedingSync.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return UploadResult(count: uploadedCount);
  }
  
  Future<List<Todo>> _compressTodos(List<Todo> todos) async {
    // Implement compression logic
    // This could involve removing redundant data, compressing JSON, etc.
    return todos.map((todo) => _optimizeTodoForSync(todo)).toList();
  }
  
  Todo _optimizeTodoForSync(Todo todo) {
    // Remove unnecessary data for sync
    // Keep only essential fields that have changed
    return todo.copyWith(
      // Only include fields that have actually changed
      syncId: todo.syncId ?? todo.id,
    );
  }
  
  void _scheduleUpload(Todo todo) {
    _pendingUploads.add(todo);
    
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchWindow, () {
      _processPendingUploads();
    });
    
    // Force upload if batch is full
    if (_pendingUploads.length >= _maxBatchSize) {
      _processPendingUploads();
    }
  }
  
  Future<void> _processPendingUploads() async {
    if (_pendingUploads.isEmpty) return;
    
    final batch = List<Todo>.from(_pendingUploads);
    _pendingUploads.clear();
    
    try {
      await _firebaseDataSource.batchSaveTodos(batch);
      
      for (final todo in batch) {
        await _todoRepository.markAsSynced(todo.id);
      }
    } catch (e) {
      // Re-add failed uploads to pending list
      _pendingUploads.addAll(batch);
      print('Batch upload failed: $e');
    }
  }
}
```

### Memory Management

```dart
// lib/core/utils/memory_manager.dart
class MemoryManager {
  static const int _maxCacheSize = 1000;
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  final Map<String, CachedTodo> _todoCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  void cacheTodo(Todo todo) {
    _cleanupExpiredCache();
    
    if (_todoCache.length >= _maxCacheSize) {
      _evictOldestCacheEntry();
    }
    
    _todoCache[todo.id] = CachedTodo(todo);
    _cacheTimestamps[todo.id] = DateTime.now();
  }
  
  Todo? getCachedTodo(String id) {
    final cached = _todoCache[id];
    final timestamp = _cacheTimestamps[id];
    
    if (cached == null || timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _todoCache.remove(id);
      _cacheTimestamps.remove(id);
      return null;
    }
    
    return cached.todo;
  }
  
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _todoCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
  
  void _evictOldestCacheEntry() {
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _todoCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }
  
  void clearCache() {
    _todoCache.clear();
    _cacheTimestamps.clear();
  }
}

class CachedTodo {
  final Todo todo;
  final DateTime cachedAt;
  
  CachedTodo(this.todo) : cachedAt = DateTime.now();
}
```

## Testing Strategies

### Unit Tests for Vector Clock

```dart
// test/domain/entities/vector_clock_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_distributed_todo_app/domain/entities/vector_clock.dart';

void main() {
  group('VectorClock', () {
    test('should create empty vector clock', () {
      const clock = VectorClock.empty();
      expect(clock.deviceIds, isEmpty);
      expect(clock.clockFor('device-a'), equals(0));
    });
    
    test('should create vector clock for device', () {
      final clock = VectorClock.forDevice('device-a', 5);
      expect(clock.clockFor('device-a'), equals(5));
      expect(clock.clockFor('device-b'), equals(0));
    });
    
    test('should increment clock for device', () {
      final clock1 = VectorClock.forDevice('device-a', 1);
      final clock2 = clock1.increment('device-a');
      
      expect(clock2.clockFor('device-a'), equals(2));
      expect(clock1.clockFor('device-a'), equals(1)); // Original unchanged
    });
    
    test('should merge vector clocks correctly', () {
      final clock1 = VectorClock({'device-a': 2, 'device-b': 1});
      final clock2 = VectorClock({'device-a': 1, 'device-b': 3, 'device-c': 1});
      
      final merged = clock1.merge(clock2);
      
      expect(merged.clockFor('device-a'), equals(2)); // max(2, 1)
      expect(merged.clockFor('device-b'), equals(3)); // max(1, 3)
      expect(merged.clockFor('device-c'), equals(1)); // max(0, 1)
    });
    
    test('should compare vector clocks for causality', () {
      final clock1 = VectorClock({'device-a': 1, 'device-b': 1});
      final clock2 = VectorClock({'device-a': 2, 'device-b': 1});
      final clock3 = VectorClock({'device-a': 1, 'device-b': 2});
      
      expect(clock1.compareTo(clock2), equals(ComparisonResult.before));
      expect(clock2.compareTo(clock1), equals(ComparisonResult.after));
      expect(clock2.compareTo(clock3), equals(ComparisonResult.concurrent));
    });
    
    test('should serialize and deserialize correctly', () {
      final original = VectorClock({'device-a': 2, 'device-b': 3});
      final json = original.toJson();
      final restored = VectorClock.fromJson(json);
      
      expect(restored, equals(original));
    });
  });
}
```

### Integration Tests for Conflict Resolution

```dart
// test/core/utils/conflict_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_distributed_todo_app/core/utils/conflict_resolver.dart';
import 'package:offline_distributed_todo_app/domain/entities/todo.dart';
import 'package:offline_distributed_todo_app/domain/entities/vector_clock.dart';

void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;
    
    setUp(() {
      resolver = ConflictResolver();
    });
    
    test('should resolve sequential changes without conflict', () {
      final todo1 = Todo.create(
        id: 'todo-1',
        name: 'Coffee',
        price: 3.50,
        deviceId: 'device-a',
      );
      
      final todo2 = todo1.updateWith(
        name: 'Premium Coffee',
        price: 4.50,
        updatingDeviceId: 'device-b',
      );
      
      final resolution = resolver.resolveConflict(
        localVersion: todo1,
        remoteVersion: todo2,
        currentDeviceId: 'device-c',
      );
      
      expect(resolution.type, equals(ResolutionType.useRemote));
      expect(resolution.mergedTodo?.name, equals('Premium Coffee'));
    });
    
    test('should auto-resolve completion-only conflicts', () {
      final baseTodo = Todo.create(
        id: 'todo-1',
        name: 'Coffee',
        price: 3.50,
        deviceId: 'device-a',
      );
      
      // Create concurrent changes - one completes, one doesn't
      final todo1 = baseTodo.copyWith(
        isCompleted: true,
        vectorClock: baseTodo.vectorClock.increment('device-b'),
        deviceId: 'device-b',
        version: 2,
      );
      
      final todo2 = baseTodo.copyWith(
        vectorClock: baseTodo.vectorClock.increment('device-c'),
        deviceId: 'device-c',
        version: 2,
      );
      
      final resolution = resolver.resolveConflict(
        localVersion: todo1,
        remoteVersion: todo2,
        currentDeviceId: 'device-d',
      );
      
      expect(resolution.type, equals(ResolutionType.useAutoMerged));
      expect(resolution.mergedTodo?.isCompleted, isTrue);
    });
    
    test('should require manual resolution for content conflicts', () {
      final baseTodo = Todo.create(
        id: 'todo-1',
        name: 'Coffee',
        price: 3.50,
        deviceId: 'device-a',
      );
      
      // Create concurrent content changes
      final todo1 = baseTodo.copyWith(
        name: 'Premium Coffee',
        price: 4.50,
        vectorClock: baseTodo.vectorClock.increment('device-b'),
        deviceId: 'device-b',
        version: 2,
      );
      
      final todo2 = baseTodo.copyWith(
        name: 'Iced Coffee',
        price: 3.75,
        vectorClock: baseTodo.vectorClock.increment('device-c'),
        deviceId: 'device-c',
        version: 2,
      );
      
      final resolution = resolver.resolveConflict(
        localVersion: todo1,
        remoteVersion: todo2,
        currentDeviceId: 'device-d',
      );
      
      expect(resolution.type, equals(ResolutionType.requiresManualResolution));
      expect(resolution.localVersion, equals(todo1));
      expect(resolution.remoteVersion, equals(todo2));
    });
  });
}
```

### Widget Tests for Conflict UI

```dart
// test/presentation/widgets/conflicts_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_distributed_todo_app/presentation/widgets/conflicts_view.dart';
import 'package:offline_distributed_todo_app/domain/entities/conflict.dart';

void main() {
  group('ConflictsView', () {
    testWidgets('should show empty state when no conflicts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conflictsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: ConflictsView(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('No conflicts to resolve'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
    
    testWidgets('should display conflicts when available', (tester) async {
      final conflicts = [
        Conflict(
          id: 'conflict-1',
          todoId: 'todo-1',
          versions: [
            Todo.create(id: 'todo-1', name: 'Coffee A', price: 4.50, deviceId: 'device-a'),
            Todo.create(id: 'todo-1', name: 'Coffee B', price: 3.75, deviceId: 'device-b'),
          ],
          detectedAt: DateTime.now(),
          type: ConflictType.contentConflict,
        ),
      ];
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conflictsProvider.overrideWith((ref) => Stream.value(conflicts)),
          ],
          child: const MaterialApp(
            home: ConflictsView(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('Conflict: todo-1'), findsOneWidget);
      expect(find.text('2 versions available'), findsOneWidget);
    });
    
    testWidgets('should show version details when expanded', (tester) async {
      final conflicts = [
        Conflict(
          id: 'conflict-1',
          todoId: 'todo-1',
          versions: [
            Todo.create(id: 'todo-1', name: 'Premium Coffee', price: 4.50, deviceId: 'device-a'),
            Todo.create(id: 'todo-1', name: 'Iced Coffee', price: 3.75, deviceId: 'device-b'),
          ],
          detectedAt: DateTime.now(),
          type: ConflictType.contentConflict,
        ),
      ];
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conflictsProvider.overrideWith((ref) => Stream.value(conflicts)),
          ],
          child: const MaterialApp(
            home: ConflictsView(),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap to expand
      await tester.tap(find.text('Conflict: todo-1'));
      await tester.pumpAndSettle();
      
      expect(find.text('Premium Coffee'), findsOneWidget);
      expect(find.text('Iced Coffee'), findsOneWidget);
      expect(find.text('\$4.50'), findsOneWidget);
      expect(find.text('\$3.75'), findsOneWidget);
    });
  });
}
```

## Deployment Considerations

### Firebase Security Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Todos collection - authenticated users can read/write their own todos
    match /todos/{todoId} {
      allow read, write: if request.auth != null;
      
      // Validate todo structure
      allow create: if validateTodoCreate();
      allow update: if validateTodoUpdate();
      
      function validateTodoCreate() {
        return request.auth != null
          && resource == null
          && request.resource.data.keys().hasAll(['id', 'name', 'price', 'vectorClock', 'deviceId']);
      }
      
      function validateTodoUpdate() {
        return request.auth != null
          && resource != null
          && request.resource.data.id == resource.data.id;
      }
    }
    
    // Conflicts collection - authenticated users can read/write conflicts
    match /conflicts/{conflictId} {
      allow read, write: if request.auth != null;
    }
    
    // Devices collection - for device tracking
    match /devices/{deviceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == deviceId;
    }
  }
}
```

### Environment Configuration

```dart
// lib/config/environment.dart
class Environment {
  static const String _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
  
  static bool get isDevelopment => _flavor == 'development';
  static bool get isStaging => _flavor == 'staging';
  static bool get isProduction => _flavor == 'production';
  
  // Sync configuration
  static Duration get syncInterval => isDevelopment 
      ? const Duration(seconds: 30)
      : const Duration(minutes: 5);
      
  static int get maxRetries => isDevelopment ? 3 : 10;
  
  static Duration get retryDelay => isDevelopment
      ? const Duration(seconds: 5)
      : const Duration(minutes: 1);
      
  // Performance settings
  static int get maxBatchSize => isProduction ? 100 : 10;
  static bool get enableCompression => isProduction;
  static bool get enableAnalytics => isProduction;
  
  // Debug settings
  static bool get verboseLogging => isDevelopment;
  static bool get showPerformanceOverlay => isDevelopment;
}
```

### Monitoring and Analytics

```dart
// lib/core/services/analytics_service.dart
class AnalyticsService {
  
  void trackSyncEvent({
    required String eventType,
    required Map<String, dynamic> parameters,
  }) {
    if (!Environment.enableAnalytics) return;
    
    // Track sync performance and conflicts
    FirebaseAnalytics.instance.logEvent(
      name: 'sync_event',
      parameters: {
        'event_type': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        ...parameters,
      },
    );
  }
  
  void trackConflictResolution({
    required String resolutionType,
    required int conflictCount,
    required Duration resolutionTime,
  }) {
    trackSyncEvent(
      eventType: 'conflict_resolution',
      parameters: {
        'resolution_type': resolutionType,
        'conflict_count': conflictCount,
        'resolution_time_ms': resolutionTime.inMilliseconds,
      },
    );
  }
  
  void trackSyncPerformance({
    required Duration syncDuration,
    required int uploadedCount,
    required int downloadedCount,
    required int conflictCount,
  }) {
    trackSyncEvent(
      eventType: 'sync_performance',
      parameters: {
        'sync_duration_ms': syncDuration.inMilliseconds,
        'uploaded_count': uploadedCount,
        'downloaded_count': downloadedCount,
        'conflict_count': conflictCount,
      },
    );
  }
}
```

This comprehensive implementation guide provides the foundation for building a robust offline-first sync system with sophisticated conflict resolution. The key is to start with the basic vector clock implementation and gradually add more advanced features as needed. 