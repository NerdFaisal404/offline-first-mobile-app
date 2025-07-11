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

    try {
      // Step 1: Upload local changes to remote
      final uploadResult = await _uploadLocalChanges();

      // Step 2: Download remote changes
      final downloadResult = await _downloadRemoteChanges();

      _isSyncing = false;

      return SyncResult.success(
        uploaded: uploadResult.count,
        downloaded: downloadResult.count,
        conflicts: downloadResult.conflicts,
      );
    } catch (e) {
      _isSyncing = false;

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
    final todosNeedingSync = await _todoRepository.getTodosNeedingSync();
    final unresolvedConflicts = await _todoRepository.getUnresolvedConflicts();
    final isConnected = await _isConnected();

    return SyncStatus(
      isConnected: isConnected,
      isSyncing: _isSyncing,
      pendingUploads: todosNeedingSync.length,
      unresolvedConflicts: unresolvedConflicts.length,
      lastSyncAttempt: DateTime.now(),
    );
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final int uploaded;
  final int downloaded;
  final int conflicts;

  SyncResult._({
    required this.success,
    this.error,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
  });

  factory SyncResult.success({
    required int uploaded,
    required int downloaded,
    required int conflicts,
  }) {
    return SyncResult._(
      success: true,
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult._(success: false, error: error);
  }

  factory SyncResult.noConnection() {
    return SyncResult._(success: false, error: 'No internet connection');
  }

  factory SyncResult.alreadyInProgress() {
    return SyncResult._(success: false, error: 'Sync already in progress');
  }
}

/// Result of uploading local changes
class UploadResult {
  final int count;

  UploadResult({required this.count});
}

/// Result of downloading remote changes
class DownloadResult {
  final int count;
  final int conflicts;

  DownloadResult({required this.count, required this.conflicts});
}

/// Current sync status
class SyncStatus {
  final bool isConnected;
  final bool isSyncing;
  final int pendingUploads;
  final int unresolvedConflicts;
  final DateTime lastSyncAttempt;

  SyncStatus({
    required this.isConnected,
    required this.isSyncing,
    required this.pendingUploads,
    required this.unresolvedConflicts,
    required this.lastSyncAttempt,
  });
}
