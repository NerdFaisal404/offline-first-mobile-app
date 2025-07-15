# Building an Offline-First Sync System with Conflict Resolution in Flutter

*A comprehensive guide to implementing distributed conflict resolution for mobile apps that work seamlessly offline*

---

## The Challenge: When Three Devices Tell Different Stories

Imagine this scenario: You have a Point of Sale (POS) system running on three tablets in a coffee shop. All devices are synced and working perfectly. Then, the WiFi goes down.

While offline, each device processes the same order differently:
- **Device A**: Updates "Coffee" to "Premium Coffee" at $4.50
- **Device B**: Changes it to "Iced Coffee" at $3.75  
- **Device C**: Makes it "Hot Coffee" at $4.00

When the network comes back, which version is correct? This is the **3-device problem** that most apps either ignore or handle poorly. Today, we'll build a robust solution that gracefully resolves these conflicts while preserving all user data.

## What We'll Build

By the end of this tutorial, you'll have:

✅ **Offline-first architecture** that works without internet  
✅ **Vector clock-based conflict detection** for distributed systems  
✅ **Automatic resolution** for simple conflicts  
✅ **Manual resolution UI** for complex conflicts  
✅ **Real-time sync** with Firebase when online  
✅ **Clean architecture** with proper separation of concerns  

## Architecture Overview

Our system uses a layered approach:

```
┌─────────────────────────────────────┐
│           Presentation Layer        │
│  ┌─────────────┐ ┌─────────────────┐│
│  │  Sync UI    │ │ Conflict Dialog ││
│  └─────────────┘ └─────────────────┘│
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│            Domain Layer             │
│  ┌─────────────┐ ┌─────────────────┐│
│  │Vector Clock │ │ Conflict Logic  ││
│  └─────────────┘ └─────────────────┘│
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│             Data Layer              │
│  ┌─────────────┐ ┌─────────────────┐│
│  │ SQLite DB   │ │   Firebase      ││
│  └─────────────┘ └─────────────────┘│
└─────────────────────────────────────┘
```

## Understanding Vector Clocks

The heart of our conflict detection system is the **Vector Clock** - a mechanism that tracks causality in distributed systems.

### How Vector Clocks Work

Each device maintains a logical clock for every device in the system:

```dart
// Initial state (all devices synced)
VectorClock: {"device-a": 1, "device-b": 1, "device-c": 1}

// After Device A makes an edit
Device A: {"device-a": 2, "device-b": 1, "device-c": 1}

// After Device B makes an edit  
Device B: {"device-a": 1, "device-b": 2, "device-c": 1}
```

### Detecting Conflicts

When comparing two vector clocks, we can determine:

- **Sequential**: One happened before the other → No conflict
- **Concurrent**: Neither dominates → Potential conflict
- **Identical**: Same logical time → No changes

```dart
enum ComparisonResult {
  before,    // This happened before other
  after,     // This happened after other  
  concurrent // Concurrent edits (potential conflict)
}
```

## Step 1: Setting Up Dependencies

First, let's set up our `pubspec.yaml` with the necessary dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # Local Database
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.1
  
  # Firebase  
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  
  # Networking
  connectivity_plus: ^5.0.2
  
  # Utilities
  uuid: ^4.2.1
  json_annotation: ^4.8.1
  equatable: ^2.0.5

dev_dependencies:
  # Code Generation
  build_runner: ^2.4.7
  drift_dev: ^2.14.1
  riverpod_generator: ^2.3.9
  json_serializable: ^6.7.1
```

## Step 2: Creating the Vector Clock

Let's implement our vector clock system:

```dart
// lib/domain/entities/vector_clock.dart
import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class VectorClock extends Equatable {
  final Map<String, int> _clocks;

  const VectorClock(this._clocks);
  const VectorClock.empty() : _clocks = const {};
  
  VectorClock.forDevice(String deviceId, int clock)
      : _clocks = {deviceId: clock};

  // Get clock value for a specific device
  int clockFor(String deviceId) => _clocks[deviceId] ?? 0;
  
  // Get all device IDs
  Set<String> get deviceIds => _clocks.keys.toSet();
  
  // Increment clock for a device
  VectorClock increment(String deviceId) {
    final newClocks = Map<String, int>.from(_clocks);
    newClocks[deviceId] = (newClocks[deviceId] ?? 0) + 1;
    return VectorClock(newClocks);
  }
  
  // Merge with another vector clock (take maximum)
  VectorClock merge(VectorClock other) {
    final newClocks = Map<String, int>.from(_clocks);
    
    for (final entry in other._clocks.entries) {
      final deviceId = entry.key;
      final otherClock = entry.value;
      newClocks[deviceId] = math.max(newClocks[deviceId] ?? 0, otherClock);
    }
    
    return VectorClock(newClocks);
  }
  
  // Compare two vector clocks for causality
  ComparisonResult compareTo(VectorClock other) {
    bool thisLessOrEqual = true;
    bool otherLessOrEqual = true;
    bool areEqual = true;
    
    final allDevices = {...deviceIds, ...other.deviceIds};
    
    for (final deviceId in allDevices) {
      final thisClock = clockFor(deviceId);
      final otherClock = other.clockFor(deviceId);
      
      if (thisClock > otherClock) {
        otherLessOrEqual = false;
        areEqual = false;
      }
      if (otherClock > thisClock) {
        thisLessOrEqual = false;
        areEqual = false;
      }
    }
    
    if (areEqual) return ComparisonResult.concurrent;
    if (thisLessOrEqual) return ComparisonResult.before;
    if (otherLessOrEqual) return ComparisonResult.after;
    return ComparisonResult.concurrent;
  }
  
  // Serialization
  Map<String, dynamic> toJson() => {'clocks': _clocks};
  
  factory VectorClock.fromJson(Map<String, dynamic> json) {
    final clocks = Map<String, int>.from(json['clocks'] ?? {});
    return VectorClock(clocks);
  }
  
  @override
  List<Object?> get props => [_clocks];
  
  @override
  String toString() => 'VectorClock($_clocks)';
}

enum ComparisonResult { before, after, concurrent }
```

## Step 3: Building the Todo Entity

Our Todo entity includes conflict resolution metadata:

```dart
// lib/domain/entities/todo.dart
import 'package:equatable/equatable.dart';
import 'vector_clock.dart';

class Todo extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Conflict resolution metadata
  final VectorClock vectorClock;
  final String deviceId; // Last editing device
  final int version; // Local version number
  final bool isDeleted; // Soft delete flag
  final String? syncId; // Firebase document ID

  const Todo({
    required this.id,
    required this.name,
    required this.price,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    required this.vectorClock,
    required this.deviceId,
    required this.version,
    this.isDeleted = false,
    this.syncId,
  });

  // Factory for creating new todos
  factory Todo.create({
    required String id,
    required String name,
    required double price,
    required String deviceId,
  }) {
    final now = DateTime.now();
    return Todo(
      id: id,
      name: name,
      price: price,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      vectorClock: VectorClock.forDevice(deviceId, 1),
      deviceId: deviceId,
      version: 1,
      isDeleted: false,
    );
  }

  // Update with new data and increment vector clock
  Todo updateWith({
    String? name,
    double? price,
    bool? isCompleted,
    required String updatingDeviceId,
  }) {
    return copyWith(
      name: name ?? this.name,
      price: price ?? this.price,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: DateTime.now(),
      vectorClock: vectorClock.increment(updatingDeviceId),
      deviceId: updatingDeviceId,
      version: version + 1,
    );
  }
  
  // Check if this todo conflicts with another version
  bool conflictsWith(Todo other) {
    return id == other.id &&
        vectorClock.isConcurrentWith(other.vectorClock) &&
        !_isIdentical(other);
  }
  
  bool _isIdentical(Todo other) {
    return name == other.name &&
        price == other.price &&
        isCompleted == other.isCompleted &&
        isDeleted == other.isDeleted;
  }

  // Standard copyWith and serialization methods...
  Todo copyWith({
    String? id,
    String? name,
    double? price,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    VectorClock? vectorClock,
    String? deviceId,
    int? version,
    bool? isDeleted,
    String? syncId,
  }) {
    return Todo(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vectorClock: vectorClock ?? this.vectorClock,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      syncId: syncId ?? this.syncId,
    );
  }
  
  @override
  List<Object?> get props => [
    id, name, price, isCompleted, createdAt, updatedAt,
    vectorClock, deviceId, version, isDeleted, syncId,
  ];
}
```

## Step 4: Implementing Conflict Resolution Logic

The conflict resolver handles the decision-making logic:

```dart
// lib/core/utils/conflict_resolver.dart
import '../../domain/entities/todo.dart';
import '../../domain/entities/vector_clock.dart';

class ConflictResolver {
  ConflictResolution resolveConflict({
    required Todo localVersion,
    required Todo remoteVersion,
    required String currentDeviceId,
  }) {
    // If identical, no conflict
    if (_todosAreIdentical(localVersion, remoteVersion)) {
      return ConflictResolution(
        type: ResolutionType.useLocal,
        mergedTodo: localVersion,
      );
    }

    // Check vector clock relationship
    final clockComparison = 
        localVersion.vectorClock.compareTo(remoteVersion.vectorClock);

    switch (clockComparison) {
      case ComparisonResult.before:
        // Local happened before remote - use remote
        return ConflictResolution(
          type: ResolutionType.useRemote,
          mergedTodo: remoteVersion,
        );

      case ComparisonResult.after:
        // Local happened after remote - use local
        return ConflictResolution(
          type: ResolutionType.useLocal,
          mergedTodo: localVersion,
        );

      case ComparisonResult.concurrent:
        // Concurrent changes - resolve conflict
        return _resolveConcurrentConflict(
            localVersion, remoteVersion, currentDeviceId);
    }
  }

  ConflictResolution _resolveConcurrentConflict(
    Todo localVersion,
    Todo remoteVersion,
    String currentDeviceId,
  ) {
    // Priority 1: Handle deletions
    if (localVersion.isDeleted != remoteVersion.isDeleted) {
      // Prefer deletion (safer operation)
      return localVersion.isDeleted
          ? ConflictResolution(type: ResolutionType.useLocal, mergedTodo: localVersion)
          : ConflictResolution(type: ResolutionType.useRemote, mergedTodo: remoteVersion);
    }

    // Priority 2: Simple completion conflicts
    if (_onlyCompletionDiffers(localVersion, remoteVersion)) {
      // Prefer completed state
      final mergedTodo = localVersion.isCompleted || remoteVersion.isCompleted
          ? (localVersion.isCompleted ? localVersion : remoteVersion)
          : localVersion;
      
      return ConflictResolution(
        type: ResolutionType.useAutoMerged,
        mergedTodo: mergedTodo,
      );
    }

    // Priority 3: Content conflicts need manual resolution
    if (_contentFieldsDiffer(localVersion, remoteVersion)) {
      return ConflictResolution(
        type: ResolutionType.requiresManualResolution,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }

    // Fallback: Use latest by clock sum
    return _useLatestByClock(localVersion, remoteVersion);
  }

  bool _todosAreIdentical(Todo local, Todo remote) {
    return local.name == remote.name &&
        local.price == remote.price &&
        local.isCompleted == remote.isCompleted &&
        local.isDeleted == remote.isDeleted;
  }

  bool _onlyCompletionDiffers(Todo local, Todo remote) {
    return local.name == remote.name &&
        local.price == remote.price &&
        local.isDeleted == remote.isDeleted &&
        local.isCompleted != remote.isCompleted;
  }

  bool _contentFieldsDiffer(Todo local, Todo remote) {
    return local.name != remote.name || local.price != remote.price;
  }

  ConflictResolution _useLatestByClock(Todo localVersion, Todo remoteVersion) {
    final localClockSum = _getVectorClockSum(localVersion.vectorClock);
    final remoteClockSum = _getVectorClockSum(remoteVersion.vectorClock);

    return localClockSum >= remoteClockSum
        ? ConflictResolution(type: ResolutionType.useLocal, mergedTodo: localVersion)
        : ConflictResolution(type: ResolutionType.useRemote, mergedTodo: remoteVersion);
  }

  int _getVectorClockSum(VectorClock vectorClock) {
    return vectorClock.clocks.values.fold(0, (sum, clock) => sum + clock);
  }
}

class ConflictResolution {
  final ResolutionType type;
  final Todo? mergedTodo;
  final Todo? localVersion;
  final Todo? remoteVersion;

  ConflictResolution({
    required this.type,
    this.mergedTodo,
    this.localVersion,
    this.remoteVersion,
  });
}

enum ResolutionType {
  useLocal,
  useRemote,
  useAutoMerged,
  requiresManualResolution,
}
```

## Step 5: Building the Sync Service

The sync service orchestrates bidirectional synchronization:

```dart
// lib/core/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  final TodoRepository _todoRepository;
  final FirebaseDataSource _firebaseDataSource;
  final LocalDatabase _localDatabase;
  final Connectivity _connectivity;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService({
    required TodoRepository todoRepository,
    required FirebaseDataSource firebaseDataSource,
    required LocalDatabase localDatabase,
    Connectivity? connectivity,
  }) : _todoRepository = todoRepository,
       _firebaseDataSource = firebaseDataSource,
       _localDatabase = localDatabase,
       _connectivity = connectivity ?? Connectivity();

  Future<void> start() async {
    print('🚀 Starting sync service...');

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Start sync if connected
    if (await _isConnected()) {
      await _performInitialSync();
      await _startRealTimeSync();
    } else {
      _startPeriodicSync();
    }
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      print('🌐 Connection restored');
      _startRealTimeSync();
    } else {
      print('📵 Connection lost - switching to offline mode');
      _startPeriodicSync();
    }
  }

  Future<SyncResult> _performSync() async {
    if (_isSyncing) return SyncResult.alreadyInProgress();
    
    _isSyncing = true;
    print('🔄 Starting sync operation...');

    try {
      // Step 1: Upload local changes
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
      print('❌ Sync failed: $e');
      return SyncResult.error(e.toString());
    }
  }

  Future<UploadResult> _uploadLocalChanges() async {
    final todosNeedingSync = await _todoRepository.getTodosNeedingSync();
    
    for (final todo in todosNeedingSync) {
      await _firebaseDataSource.saveTodo(todo);
      await _todoRepository.markAsSynced(todo.id);
    }
    
    return UploadResult(count: todosNeedingSync.length);
  }

  Future<DownloadResult> _downloadRemoteChanges() async {
    final remoteTodos = await _firebaseDataSource.getAllTodos();
    int conflictCount = 0;
    
    for (final remoteTodo in remoteTodos) {
      final localTodo = await _todoRepository.getTodoById(remoteTodo.id);
      
      if (localTodo != null) {
        // Check for conflicts
        final resolution = _conflictResolver.resolveConflict(
          localVersion: localTodo,
          remoteVersion: remoteTodo,
          currentDeviceId: await _getDeviceId(),
        );
        
        if (resolution.type == ResolutionType.requiresManualResolution) {
          // Create conflict for manual resolution
          await _todoRepository.createConflict(Conflict(
            id: _uuid.v4(),
            todoId: remoteTodo.id,
            versions: [localTodo, remoteTodo],
            detectedAt: DateTime.now(),
            type: ConflictType.contentConflict,
          ));
          conflictCount++;
        } else {
          // Apply automatic resolution
          await _todoRepository.updateTodo(resolution.mergedTodo!);
        }
      } else {
        // New todo from remote
        await _todoRepository.createTodo(remoteTodo);
      }
    }
    
    return DownloadResult(
      count: remoteTodos.length,
      conflicts: conflictCount,
    );
  }

  // Additional helper methods...
}
```

## Step 6: Creating the Conflict Resolution UI

Now let's build the user interface for conflict resolution:

```dart
// lib/presentation/widgets/conflicts_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConflictsView extends ConsumerWidget {
  const ConflictsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => _autoResolveAll(ref),
            tooltip: 'Auto-resolve all conflicts',
          ),
        ],
      ),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading conflicts: $error'),
        ),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No conflicts to resolve'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return ConflictCard(conflict: conflict);
            },
          );
        },
      ),
    );
  }

  void _autoResolveAll(WidgetRef ref) {
    ref.read(todoRepositoryProvider).autoResolveAllConflicts();
  }
}

class ConflictCard extends ConsumerWidget {
  final Conflict conflict;
  
  const ConflictCard({super.key, required this.conflict});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text('Conflict: ${conflict.todoId}'),
        subtitle: Text('${conflict.versions.length} versions available'),
        children: [
          ...conflict.versions.map((version) => 
            VersionTile(
              version: version,
              onSelect: () => _selectVersion(ref, version),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _openManualMerge(context, ref),
                  child: const Text('Manual Merge'),
                ),
                ElevatedButton(
                  onPressed: () => _autoResolve(ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Auto Resolve'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectVersion(WidgetRef ref, Todo version) {
    ref.read(todoRepositoryProvider).resolveConflictWithVersion(
      conflict.id,
      version,
    );
  }

  void _autoResolve(WidgetRef ref) {
    ref.read(todoRepositoryProvider).autoResolveConflict(conflict.id);
  }

  void _openManualMerge(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ManualMergeDialog(conflict: conflict),
    );
  }
}

class VersionTile extends StatelessWidget {
  final Todo version;
  final VoidCallback onSelect;

  const VersionTile({
    super.key,
    required this.version,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(version.name),
      subtitle: Text('\$${version.price.toStringAsFixed(2)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Device: ${version.deviceId}'),
          Text('Version: ${version.version}'),
        ],
      ),
      onTap: onSelect,
    );
  }
}
```

## Step 7: Adding Real-Time Sync Status

Let's create a sync status bar to show users what's happening:

```dart
// lib/presentation/widgets/sync_status_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusAsync = ref.watch(syncStatusProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(syncStatusAsync),
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(syncStatusAsync),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimaryText(syncStatusAsync),
                _buildSecondaryText(syncStatusAsync),
              ],
            ),
          ),
          _buildActionButton(context, ref, syncStatusAsync),
        ],
      ),
    );
  }

  Color _getStatusColor(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected) return Colors.red.shade100;
        if (status.isSyncing) return Colors.blue.shade100;
        if (status.unresolvedConflicts > 0) return Colors.orange.shade100;
        if (status.pendingUploads > 0) return Colors.yellow.shade100;
        return Colors.green.shade100;
      },
      loading: () => Colors.grey.shade100,
      error: (_, __) => Colors.red.shade100,
    );
  }

  Widget _buildStatusIcon(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected)
          return const Icon(Icons.cloud_off, color: Colors.red, size: 20);
        if (status.isSyncing)
          return const Icon(Icons.sync, color: Colors.blue, size: 20);
        if (status.unresolvedConflicts > 0)
          return const Icon(Icons.warning, color: Colors.orange, size: 20);
        if (status.pendingUploads > 0)
          return const Icon(Icons.cloud_upload, color: Colors.orange, size: 20);
        return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
      },
      loading: () => const Icon(Icons.refresh, color: Colors.grey, size: 20),
      error: (_, __) => const Icon(Icons.error, color: Colors.red, size: 20),
    );
  }

  Widget _buildPrimaryText(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected)
          return const Text('Offline', style: TextStyle(fontWeight: FontWeight.bold));
        if (status.isSyncing)
          return const Text('Syncing...', style: TextStyle(fontWeight: FontWeight.bold));
        if (status.unresolvedConflicts > 0)
          return Text('${status.unresolvedConflicts} conflicts', 
              style: const TextStyle(fontWeight: FontWeight.bold));
        if (status.pendingUploads > 0)
          return Text('${status.pendingUploads} pending', 
              style: const TextStyle(fontWeight: FontWeight.bold));
        return const Text('All synced', style: TextStyle(fontWeight: FontWeight.bold));
      },
      loading: () => const Text('Loading...', style: TextStyle(fontWeight: FontWeight.bold)),
      error: (_, __) => const Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSecondaryText(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected)
          return const Text('Working offline', style: TextStyle(fontSize: 12));
        if (status.lastSyncAt != null)
          return Text('Last sync: ${_formatTime(status.lastSyncAt!)}', 
              style: const TextStyle(fontSize: 12));
        return const Text('Tap to sync', style: TextStyle(fontSize: 12));
      },
      loading: () => const Text('Initializing...', style: TextStyle(fontSize: 12)),
      error: (_, __) => const Text('Sync failed', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SyncStatus> syncStatusAsync,
  ) {
    return syncStatusAsync.when(
      data: (status) {
        if (status.unresolvedConflicts > 0) {
          return ElevatedButton(
            onPressed: () => ref.read(showConflictsProvider.notifier).state = true,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Resolve'),
          );
        }
        if (!status.isSyncing) {
          return IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(syncServiceProvider).forceSync(),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.read(syncServiceProvider).forceSync(),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

## Testing Your Sync System

### Method 1: Multi-Device Testing

1. **Set up multiple simulators:**
```bash
# Terminal 1 - iOS
flutter run -d "iPhone 15 Pro"

# Terminal 2 - Android  
flutter run -d "Android Emulator"

# Terminal 3 - Web
flutter run -d chrome
```

2. **Create the conflict scenario:**
   - Create a todo on all devices
   - Disconnect all devices from internet
   - Edit the same todo differently on each device
   - Reconnect to internet
   - Watch conflict resolution in action

### Method 2: Network Simulation

```dart
// For testing purposes, you can simulate network conditions
class NetworkSimulator {
  static bool _isOffline = false;
  
  static void goOffline() {
    _isOffline = true;
    // Your sync service should detect this
  }
  
  static void goOnline() {
    _isOffline = false;
    // Trigger sync when back online
  }
  
  static bool get isConnected => !_isOffline;
}
```

## Sync Status Indicators

Your app should clearly communicate sync state to users:

- 🟢 **Green**: All data synced
- 🟡 **Yellow**: Pending uploads  
- 🔵 **Blue**: Currently syncing
- 🟠 **Orange**: Conflicts detected
- 🔴 **Red**: Offline/error

## Best Practices & Considerations

### Performance Optimization

1. **Batch Operations**: Group multiple changes together
2. **Incremental Sync**: Only sync changed data
3. **Background Sync**: Use background tasks for sync operations
4. **Compression**: Compress data for network transfer

### Error Handling

```dart
class SyncErrorHandler {
  static void handleSyncError(SyncError error) {
    switch (error.type) {
      case SyncErrorType.networkError:
        // Retry with exponential backoff
        _scheduleRetry(error);
        break;
      case SyncErrorType.authError:
        // Re-authenticate user
        _handleAuthError(error);
        break;
      case SyncErrorType.conflictError:
        // Present conflict resolution UI
        _showConflictResolution(error);
        break;
    }
  }
}
```

### Data Consistency

- **Atomic Operations**: Ensure operations are all-or-nothing
- **Transaction Support**: Use database transactions for consistency
- **Validation**: Validate data before applying changes
- **Rollback**: Support rolling back failed operations

## Conclusion

You've now built a robust offline-first sync system that can handle the complex 3-device scenario. Your app can:

✅ Work completely offline with local storage  
✅ Detect conflicts using vector clocks  
✅ Automatically resolve simple conflicts  
✅ Present complex conflicts to users for manual resolution  
✅ Maintain data consistency across all devices  

The key insights from this implementation:

1. **Vector clocks** provide reliable conflict detection in distributed systems
2. **Layered conflict resolution** handles different types of conflicts appropriately  
3. **Clear UI feedback** helps users understand and resolve conflicts
4. **Robust error handling** ensures the system degrades gracefully

This pattern can be extended to any type of data that needs offline-first synchronization with conflict resolution. The principles apply whether you're building a POS system, collaborative editor, or any app that needs to work seamlessly offline.

**Next Steps:**
- Add more sophisticated merge algorithms
- Implement operational transform for real-time collaboration
- Add data compression for better performance
- Implement background sync for better UX

---

*🎯 **Pro Tip**: Test your conflict resolution extensively with real network conditions. Edge cases in offline sync can be subtle but critical to user experience.*

---

**Source Code**: The complete implementation is available in the [GitHub repository](https://github.com/NerdFaisal404/offline-first-mobile-app) with detailed documentation and examples.

*Happy coding! 🚀* 