import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../data/datasources/firebase_datasource.dart';

/// Service that handles bidirectional sync between local and remote data
class SyncService {
  final TodoRepository _todoRepository;
  final FirebaseDataSource _firebaseDataSource;
  final Connectivity _connectivity;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _retryDelay = Duration(seconds: 30);

  SyncService({
    required TodoRepository todoRepository,
    required FirebaseDataSource firebaseDataSource,
    Connectivity? connectivity,
  })  : _todoRepository = todoRepository,
        _firebaseDataSource = firebaseDataSource,
        _connectivity = connectivity ?? Connectivity();

  /// Start the sync service
  Future<void> start() async {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Start periodic sync
    _startPeriodicSync();

    // Perform initial sync if connected
    if (await _isConnected()) {
      _scheduleSync();
    }
  }

  /// Stop the sync service
  void stop() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Force a sync operation
  Future<SyncResult> forcSync() async {
    if (_isSyncing) {
      return SyncResult.alreadyInProgress();
    }

    if (!await _isConnected()) {
      return SyncResult.noConnection();
    }

    return await _performSync();
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      // Connection restored - sync immediately
      _scheduleSync();
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _scheduleSync();
    });
  }

  /// Schedule a sync operation
  void _scheduleSync() {
    if (_isSyncing) return;

    Timer(Duration.zero, () async {
      if (await _isConnected()) {
        await _performSync();
      }
    });
  }

  /// Perform the actual sync operation
  Future<SyncResult> _performSync() async {
    _isSyncing = true;
    print('🔄 Starting sync operation...');

    try {
      // Step 1: Upload local changes to remote
      print('📤 Uploading local changes...');
      final uploadResult = await _uploadLocalChanges();
      print('📤 Uploaded ${uploadResult.count} todos');

      // Step 2: Download remote changes
      print('📥 Downloading remote changes...');
      final downloadResult = await _downloadRemoteChanges();
      print(
          '📥 Downloaded ${downloadResult.count} todos, ${downloadResult.conflicts} conflicts');

      _isSyncing = false;

      final result = SyncResult.success(
        uploaded: uploadResult.count,
        downloaded: downloadResult.count,
        conflicts: downloadResult.conflicts,
      );

      print('✅ Sync completed successfully');
      return result;
    } catch (e) {
      _isSyncing = false;
      print('❌ Sync failed: $e');

      // Retry after delay
      Timer(_retryDelay, () => _scheduleSync());

      return SyncResult.error(e.toString());
    }
  }

  /// Upload local changes to Firebase
  Future<UploadResult> _uploadLocalChanges() async {
    final todosNeedingSync = await _todoRepository.getTodosNeedingSync();

    if (todosNeedingSync.isEmpty) {
      return UploadResult(count: 0);
    }

    int uploadedCount = 0;

    for (final todo in todosNeedingSync) {
      try {
        if (todo.isDeleted && todo.syncId != null) {
          // Delete from remote
          await _firebaseDataSource.deleteTodo(todo.syncId!);
          await _todoRepository.deleteTodo(todo.id); // Remove from local DB
        } else if (!todo.isDeleted) {
          // Upload to remote
          final syncId = await _firebaseDataSource.uploadTodo(todo);
          await _todoRepository.markTodoSynced(todo.id, syncId);
        }
        uploadedCount++;
      } catch (e) {
        // Log error but continue with other todos
        print('Failed to sync todo ${todo.id}: $e');
      }
    }

    return UploadResult(count: uploadedCount);
  }

  /// Download remote changes from Firebase
  Future<DownloadResult> _downloadRemoteChanges() async {
    try {
      final remoteTodos = await _firebaseDataSource.downloadTodos();

      // Get unresolved conflicts before sync
      final conflictsBefore = await _todoRepository.getUnresolvedConflicts();

      // Process remote todos (this handles conflict resolution)
      await _todoRepository.syncFromRemote(remoteTodos);

      // Get unresolved conflicts after sync
      final conflictsAfter = await _todoRepository.getUnresolvedConflicts();

      return DownloadResult(
        count: remoteTodos.length,
        conflicts: conflictsAfter.length - conflictsBefore.length,
      );
    } catch (e) {
      throw Exception('Failed to download remote changes: $e');
    }
  }

  /// Check if device is connected to the internet
  Future<bool> _isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      isConnected: await _isConnected(),
      isSyncing: _isSyncing,
      lastSyncTime: DateTime.now(), // You might want to store this
    );
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final String? error;

  SyncResult({
    required this.success,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.error,
  });

  factory SyncResult.success({
    int uploaded = 0,
    int downloaded = 0,
    int conflicts = 0,
  }) {
    return SyncResult(
      success: true,
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult(success: false, error: error);
  }

  factory SyncResult.noConnection() {
    return SyncResult(success: false, error: 'No internet connection');
  }

  factory SyncResult.alreadyInProgress() {
    return SyncResult(success: false, error: 'Sync already in progress');
  }
}

/// Upload result
class UploadResult {
  final int count;

  UploadResult({required this.count});
}

/// Download result
class DownloadResult {
  final int count;
  final int conflicts;

  DownloadResult({required this.count, this.conflicts = 0});
}

/// Sync status information
class SyncStatus {
  final bool isConnected;
  final bool isSyncing;
  final DateTime lastSyncTime;

  SyncStatus({
    required this.isConnected,
    required this.isSyncing,
    required this.lastSyncTime,
  });
}
