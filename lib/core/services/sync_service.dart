import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/entities/todo.dart';
import '../../domain/entities/conflict.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../data/datasources/firebase_datasource.dart';
import '../../data/datasources/local_database.dart';

/// Service that handles bidirectional sync between local and remote data
class SyncService {
  final TodoRepository _todoRepository;
  final FirebaseDataSource _firebaseDataSource;
  final LocalDatabase _localDatabase;
  final Connectivity _connectivity;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _firebaseTodosSubscription;
  StreamSubscription? _firebaseDevicesSubscription;
  StreamSubscription? _firebaseConflictsSubscription;
  bool _isSyncing = false;
  bool _isRealTimeSyncActive = false;

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _retryDelay = Duration(seconds: 30);
  static const Duration _deviceHeartbeat = Duration(minutes: 2);

  SyncService({
    required TodoRepository todoRepository,
    required FirebaseDataSource firebaseDataSource,
    required LocalDatabase localDatabase,
    Connectivity? connectivity,
  })  : _todoRepository = todoRepository,
        _firebaseDataSource = firebaseDataSource,
        _localDatabase = localDatabase,
        _connectivity = connectivity ?? Connectivity();

  /// Start the sync service
  Future<void> start() async {
    print('🚀 Starting sync service...');

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Perform initial sync if connected
    if (await _isConnected()) {
      await _performInitialSync();
      await _startRealTimeSync();
    } else {
      print('📵 No connection - starting offline mode');
      _startPeriodicSync();
    }

    print('✅ Sync service started');
  }

  /// Stop the sync service
  void stop() {
    print('🛑 Stopping sync service...');
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _firebaseTodosSubscription?.cancel();
    _firebaseDevicesSubscription?.cancel();
    _firebaseConflictsSubscription?.cancel();
    _isRealTimeSyncActive = false;
    print('✅ Sync service stopped');
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
      print('🌐 Connection restored');
      // Connection restored - start real-time sync
      _startRealTimeSync().catchError((e) {
        print('❌ Failed to start real-time sync: $e');
        _startPeriodicSync();
      });
    } else {
      print('📵 Connection lost - switching to offline mode');
      _firebaseTodosSubscription?.cancel();
      _firebaseDevicesSubscription?.cancel();
      _firebaseConflictsSubscription?.cancel();
      _isRealTimeSyncActive = false;
      _startPeriodicSync();
    }
  }

  /// Perform initial sync when app starts
  Future<void> _performInitialSync() async {
    print('🔄 Performing initial sync...');

    try {
      // Sync current device info
      await _syncCurrentDevice();

      // Perform regular sync
      final result = await _performSync();
      print('✅ Initial sync completed: ${result.toString()}');
    } catch (e) {
      print('❌ Initial sync failed: $e');
      rethrow;
    }
  }

  /// Start real-time sync with Firebase streams
  Future<void> _startRealTimeSync() async {
    if (_isRealTimeSyncActive) return;

    print('📡 Starting real-time sync...');

    try {
      // Cancel periodic sync since we're going real-time
      _syncTimer?.cancel();

      // Listen to Firebase todos changes
      _firebaseTodosSubscription = _firebaseDataSource.watchTodos().listen(
        (remoteTodos) {
          print('📥 Received ${remoteTodos.length} todos from Firebase');
          _processTodosFromFirebase(remoteTodos).catchError((e) {
            print('❌ Error processing Firebase todos: $e');
          });
        },
        onError: (e) {
          print('❌ Firebase todos stream error: $e');
          _startPeriodicSync(); // Fallback to periodic sync
        },
      );

      // Listen to Firebase devices changes
      _firebaseDevicesSubscription = _firebaseDataSource.watchDevices().listen(
        (remoteDevices) {
          print('📱 Received ${remoteDevices.length} devices from Firebase');
          _processDevicesFromFirebase(remoteDevices).catchError((e) {
            print('❌ Error processing Firebase devices: $e');
          });
        },
        onError: (e) {
          print('❌ Firebase devices stream error: $e');
        },
      );

      // Listen to Firebase conflicts changes
      _firebaseConflictsSubscription =
          _firebaseDataSource.watchConflicts().listen(
        (remoteConflicts) {
          print(
              '⚠️ Received ${remoteConflicts.length} conflicts from Firebase');
          _processConflictsFromFirebase(remoteConflicts).catchError((e) {
            print('❌ Error processing Firebase conflicts: $e');
          });
        },
        onError: (e) {
          print('❌ Firebase conflicts stream error: $e');
        },
      );

      // Start device heartbeat
      _startDeviceHeartbeat();

      _isRealTimeSyncActive = true;
      print('✅ Real-time sync active');
    } catch (e) {
      print('❌ Failed to start real-time sync: $e');
      _startPeriodicSync(); // Fallback to periodic sync
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

      // Clean up local deleted todos that are confirmed deleted remotely
      await _cleanupDeletedTodos(remoteTodos);

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

  // =============================================================================
  // REAL-TIME SYNC METHODS
  // =============================================================================

  /// Sync current device information to Firebase
  Future<void> _syncCurrentDevice() async {
    try {
      final deviceId = await _todoRepository.getCurrentDeviceId();

      // Get device data from local database
      final devices = await (_localDatabase.select(_localDatabase.devices)
            ..where((d) => d.id.equals(deviceId)))
          .get();

      if (devices.isNotEmpty) {
        await _firebaseDataSource.uploadDevice(devices.first);
        print('📱 Synced current device to Firebase');
      }
    } catch (e) {
      print('❌ Failed to sync current device: $e');
    }
  }

  /// Process todos received from Firebase real-time stream
  Future<void> _processTodosFromFirebase(List<Todo> remoteTodos) async {
    try {
      // Use existing sync logic from repository
      await _todoRepository.syncFromRemote(remoteTodos);
      print('✅ Processed ${remoteTodos.length} todos from Firebase stream');
    } catch (e) {
      print('❌ Failed to process Firebase todos: $e');
    }
  }

  /// Process devices received from Firebase real-time stream
  Future<void> _processDevicesFromFirebase(
      List<DeviceData> remoteDevices) async {
    try {
      // Update local devices table with remote devices
      for (final remoteDevice in remoteDevices) {
        // First check if device exists, then update or insert
        final existingDevices =
            await (_localDatabase.select(_localDatabase.devices)
                  ..where((d) => d.id.equals(remoteDevice.id)))
                .get();
        final existingDevice =
            existingDevices.isNotEmpty ? existingDevices.first : null;

        if (existingDevice != null) {
          // Update existing device
          await (_localDatabase.update(_localDatabase.devices)
                ..where((d) => d.id.equals(remoteDevice.id)))
              .write(remoteDevice.toCompanion(false));
        } else {
          // Insert new device
          await _localDatabase
              .into(_localDatabase.devices)
              .insert(remoteDevice.toCompanion(false));
        }
      }
      print('✅ Processed ${remoteDevices.length} devices from Firebase stream');
    } catch (e) {
      print('❌ Failed to process Firebase devices: $e');
    }
  }

  /// Process conflicts received from Firebase real-time stream
  Future<void> _processConflictsFromFirebase(
      List<Conflict> remoteConflicts) async {
    try {
      final localConflicts = await _todoRepository.getUnresolvedConflicts();

      for (final remoteConflict in remoteConflicts) {
        // Check if conflict already exists locally
        final existsLocally =
            localConflicts.any((c) => c.id == remoteConflict.id);

        if (!existsLocally) {
          await _todoRepository.createConflict(remoteConflict);
        } else {
          // Update existing conflict
          await _todoRepository.resolveConflict(remoteConflict);
        }
      }
      print(
          '✅ Processed ${remoteConflicts.length} conflicts from Firebase stream');
    } catch (e) {
      print('❌ Failed to process Firebase conflicts: $e');
    }
  }

  /// Start device heartbeat to update last seen timestamp
  void _startDeviceHeartbeat() {
    Timer.periodic(_deviceHeartbeat, (timer) async {
      if (!_isRealTimeSyncActive) {
        timer.cancel();
        return;
      }

      try {
        final deviceId = await _todoRepository.getCurrentDeviceId();
        await _firebaseDataSource.updateDeviceLastSeen(deviceId);
        print('💓 Device heartbeat sent');
      } catch (e) {
        print('❌ Failed to send device heartbeat: $e');
      }
    });
  }

  /// Clean up local deleted todos that are confirmed deleted remotely
  Future<void> _cleanupDeletedTodos(List<Todo> remoteTodos) async {
    try {
      final localTodos = await _todoRepository.getAllTodos();
      final localDeletedTodos = localTodos.where((t) => t.isDeleted).toList();

      for (final localDeleted in localDeletedTodos) {
        // Check if this deleted todo exists in remote (should not if properly deleted)
        final existsInRemote = remoteTodos.any((r) => r.id == localDeleted.id);

        if (!existsInRemote) {
          // Todo is deleted locally and doesn't exist remotely - safe to permanently delete
          await _localDatabase.deleteTodo(localDeleted.id);
          print('🗑️ Permanently deleted todo: ${localDeleted.name}');
        }
      }
    } catch (e) {
      print('❌ Failed to cleanup deleted todos: $e');
    }
  }

  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    final todosNeedingSync = await _todoRepository.getTodosNeedingSync();
    final unresolvedConflicts = await _todoRepository.getUnresolvedConflicts();

    return SyncStatus(
      isConnected: await _isConnected(),
      isSyncing: _isSyncing,
      lastSyncTime: DateTime.now(), // You might want to store this
      pendingUploads: todosNeedingSync.length,
      unresolvedConflicts: unresolvedConflicts.length,
      lastSyncAttempt: DateTime.now(), // You might want to store this
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
  final int pendingUploads;
  final int unresolvedConflicts;
  final DateTime lastSyncAttempt;

  SyncStatus({
    required this.isConnected,
    required this.isSyncing,
    required this.lastSyncTime,
    required this.pendingUploads,
    required this.unresolvedConflicts,
    required this.lastSyncAttempt,
  });
}
