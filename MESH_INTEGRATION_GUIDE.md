# Mesh Networking Integration Guide

This guide shows how to integrate the mesh networking system with your existing offline distributed todo app.

## Integration Overview

The mesh networking system extends your existing architecture without breaking changes. It adds a new layer that can operate alongside Firebase sync.

## Step 1: Update Dependencies

First, install the required dependencies:

```bash
flutter pub get
```

## Step 2: Create Enhanced Sync Service

Create an enhanced sync service that supports both Firebase and mesh networking:

```dart
// lib/core/services/enhanced_sync_service.dart
import 'dart:async';

import '../services/sync_service.dart';
import '../services/mesh_sync_service.dart';
import '../services/mesh_discovery_service.dart';
import '../services/mesh_communication_service.dart';
import '../../data/datasources/mesh_datasource.dart';
import '../../domain/entities/sync_plan.dart';

class EnhancedSyncService extends SyncService {
  final MeshDataSource _meshDataSource;
  final String _deviceId;
  
  EnhancedSyncService({
    required super.todoRepository,
    required super.firebaseDataSource,
    required super.localDatabase,
    required MeshDataSource meshDataSource,
    required String deviceId,
    super.connectivity,
  }) : _meshDataSource = meshDataSource,
       _deviceId = deviceId;

  @override
  Future<void> start() async {
    print('🚀 Starting enhanced sync service (Firebase + Mesh)...');
    
    // Start Firebase sync
    await super.start();
    
    // Start mesh networking
    await _meshDataSource.initialize();
    
    print('✅ Enhanced sync service started');
  }

  @override
  void stop() {
    print('🛑 Stopping enhanced sync service...');
    
    // Stop mesh networking
    _meshDataSource.stop();
    
    // Stop Firebase sync
    super.stop();
    
    print('✅ Enhanced sync service stopped');
  }

  @override
  Future<SyncResult> forcSync() async {
    final results = <SyncResult>[];
    
    // Firebase sync
    try {
      final firebaseResult = await super.forcSync();
      results.add(firebaseResult);
    } catch (e) {
      print('❌ Firebase sync failed: $e');
    }
    
    // Mesh sync
    try {
      final meshResults = await _meshDataSource.syncWithAllPeers();
      // Convert mesh results to sync results
      for (final meshResult in meshResults) {
        results.add(SyncResult.success(
          uploaded: meshResult.todosSent,
          downloaded: meshResult.todosReceived,
          conflicts: meshResult.conflictsDetected,
        ));
      }
    } catch (e) {
      print('❌ Mesh sync failed: $e');
    }
    
    return SyncResult.combined(results);
  }

  /// Get mesh network status
  MeshNetworkStatus getMeshStatus() {
    return _meshDataSource.getNetworkStatus();
  }

  /// Force mesh sync only
  Future<List<MeshSyncResult>> forceMeshSync() async {
    return await _meshDataSource.syncWithAllPeers();
  }

  /// Broadcast todo to mesh network
  Future<void> broadcastTodoToMesh(Todo todo) async {
    await _meshDataSource.broadcastTodo(todo);
  }
}
```

## Step 3: Update App Providers

Update your app providers to include mesh networking:

```dart
// lib/presentation/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/local_database.dart';
import '../../data/datasources/firebase_datasource.dart';
import '../../data/datasources/mesh_datasource.dart';
import '../../data/repositories/todo_repository_impl.dart';
import '../../core/utils/conflict_resolver.dart';
import '../../core/services/enhanced_sync_service.dart';
import '../../core/services/mesh_discovery_service.dart';
import '../../core/services/mesh_communication_service.dart';
import '../../core/services/mesh_sync_service.dart';

// Device ID provider (should be persistent)
final deviceIdProvider = Provider<String>((ref) {
  // In a real app, get this from secure storage or device info
  return const Uuid().v4();
});

// Local database provider
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

// Firebase datasource provider
final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

// Conflict resolver provider
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

// Mesh discovery service provider
final meshDiscoveryServiceProvider = Provider<MeshDiscoveryService>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  return MeshDiscoveryService(
    deviceId: deviceId,
    deviceName: 'Flutter Device', // Get from device info
  );
});

// Mesh communication service provider
final meshCommunicationServiceProvider = Provider<MeshCommunicationService>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  return MeshCommunicationService(deviceId: deviceId);
});

// Mesh sync service provider
final meshSyncServiceProvider = Provider<MeshSyncService>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  final todoRepository = ref.watch(todoRepositoryProvider);
  final conflictResolver = ref.watch(conflictResolverProvider);
  final discoveryService = ref.watch(meshDiscoveryServiceProvider);
  final communicationService = ref.watch(meshCommunicationServiceProvider);
  
  return MeshSyncService(
    deviceId: deviceId,
    todoRepository: todoRepository,
    conflictResolver: conflictResolver,
    discoveryService: discoveryService,
    communicationService: communicationService,
  );
});

// Mesh datasource provider
final meshDataSourceProvider = Provider<MeshDataSource>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  final syncService = ref.watch(meshSyncServiceProvider);
  final discoveryService = ref.watch(meshDiscoveryServiceProvider);
  final communicationService = ref.watch(meshCommunicationServiceProvider);
  
  return MeshDataSource(
    deviceId: deviceId,
    syncService: syncService,
    discoveryService: discoveryService,
    communicationService: communicationService,
  );
});

// Enhanced sync service provider
final enhancedSyncServiceProvider = Provider<EnhancedSyncService>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  final todoRepository = ref.watch(todoRepositoryProvider);
  final localDatabase = ref.watch(localDatabaseProvider);
  final firebaseDataSource = ref.watch(firebaseDataSourceProvider);
  final meshDataSource = ref.watch(meshDataSourceProvider);
  
  return EnhancedSyncService(
    deviceId: deviceId,
    todoRepository: todoRepository,
    localDatabase: localDatabase,
    firebaseDataSource: firebaseDataSource,
    meshDataSource: meshDataSource,
  );
});

// TODO: Update existing todoRepositoryProvider to use enhanced sync
final todoRepositoryProvider = Provider<TodoRepositoryImpl>((ref) {
  final localDatabase = ref.watch(localDatabaseProvider);
  final firebaseDataSource = ref.watch(firebaseDataSourceProvider);
  final meshDataSource = ref.watch(meshDataSourceProvider);
  final conflictResolver = ref.watch(conflictResolverProvider);
  
  return TodoRepositoryImpl(
    localDatabase: localDatabase,
    firebaseDataSource: firebaseDataSource,
    meshDataSource: meshDataSource, // Add this parameter
    conflictResolver: conflictResolver,
  );
});
```

## Step 4: Update TodoRepositoryImpl

Extend your existing repository to support mesh networking:

```dart
// lib/data/repositories/todo_repository_impl.dart (additions)
import '../datasources/mesh_datasource.dart';

class TodoRepositoryImpl implements TodoRepository {
  final LocalDatabase _localDatabase;
  final FirebaseDataSource _firebaseDataSource;
  final MeshDataSource _meshDataSource; // Add this
  final ConflictResolver _conflictResolver;
  
  // ... existing code ...

  TodoRepositoryImpl({
    required LocalDatabase localDatabase,
    required FirebaseDataSource firebaseDataSource,
    required MeshDataSource meshDataSource, // Add this parameter
    required ConflictResolver conflictResolver,
  }) : _localDatabase = localDatabase,
       _firebaseDataSource = firebaseDataSource,
       _meshDataSource = meshDataSource,
       _conflictResolver = conflictResolver;

  @override
  Future<void> createTodo(Todo todo) async {
    await _localDatabase.insertTodo(todo);
    
    // Broadcast to mesh network immediately
    await _meshDataSource.broadcastTodo(todo);
    
    _emitTodosUpdate();
    _triggerSync();
  }

  @override
  Future<void> updateTodo(Todo todo) async {
    await _localDatabase.updateTodo(todo);
    
    // Send update to mesh network
    await _meshDataSource.sendTodoUpdate(todo);
    
    _emitTodosUpdate();
    _triggerSync();
  }

  @override
  Future<void> deleteTodo(String id) async {
    final todo = await _localDatabase.getTodoById(id);
    if (todo != null) {
      await _localDatabase.deleteTodo(id);
      
      // Send deletion to mesh network
      await _meshDataSource.sendTodoDelete(todo);
    }
    
    _emitTodosUpdate();
    _triggerSync();
  }

  /// Get mesh network status
  MeshNetworkStatus getMeshStatus() {
    return _meshDataSource.getNetworkStatus();
  }

  /// Force mesh sync
  Future<List<MeshSyncResult>> forceMeshSync() async {
    return await _meshDataSource.syncWithAllPeers();
  }
}
```

## Step 5: Add Mesh Status Widget

Create a widget to show mesh networking status:

```dart
// lib/presentation/widgets/mesh_status_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../../data/datasources/mesh_datasource.dart';

class MeshStatusWidget extends ConsumerWidget {
  const MeshStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meshDataSource = ref.watch(meshDataSourceProvider);
    
    return StreamBuilder<MeshNetworkStatus>(
      stream: meshDataSource.watchNetworkStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        
        if (status == null) {
          return const SizedBox.shrink();
        }
        
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      status.isHealthy ? Icons.wifi : Icons.wifi_off,
                      color: status.isHealthy ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mesh Network',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(status.isActive ? 'Active' : 'Inactive'),
                      backgroundColor: status.isActive ? Colors.green[100] : Colors.grey[200],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusItem('Peers', status.availablePeersCount.toString()),
                    const SizedBox(width: 16),
                    _StatusItem('Connected', status.connectedPeersCount.toString()),
                    const SizedBox(width: 16),
                    _StatusItem('Syncing', status.activeSyncsCount.toString()),
                  ],
                ),
                if (status.peers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text('Available Peers:'),
                  const SizedBox(height: 4),
                  ...status.peers.take(3).map((peer) => 
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '• ${peer.deviceName} (${peer.ipAddress})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (status.peers.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '• +${status.peers.length - 3} more...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  
  const _StatusItem(this.label, this.value);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

## Step 6: Update Todo Home Page

Update your main page to include mesh networking:

```dart
// lib/presentation/pages/todo_home_page.dart (additions)
import '../widgets/mesh_status_widget.dart';

class TodoHomePage extends ConsumerStatefulWidget {
  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributed Todos'),
        actions: [
          // Add mesh sync button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => _forceMeshSync(ref),
            tooltip: 'Force Mesh Sync',
          ),
          // ... existing actions ...
        ],
      ),
      body: Column(
        children: [
          // Add mesh status widget
          const MeshStatusWidget(),
          
          // Existing sync status bar
          const SyncStatusBar(),
          
          // Existing todo list
          const Expanded(child: TodoList()),
        ],
      ),
      // ... existing floating action button ...
    );
  }

  Future<void> _forceMeshSync(WidgetRef ref) async {
    final meshDataSource = ref.read(meshDataSourceProvider);
    try {
      final results = await meshDataSource.syncWithAllPeers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesh sync completed: ${results.length} peers'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesh sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
```

## Step 7: Initialize Enhanced Sync Service

Update your main.dart to use the enhanced sync service:

```dart
// main.dart (additions)
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (existing code)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize enhanced sync service
    ref.listen(enhancedSyncServiceProvider, (previous, next) {
      if (previous == null) {
        // Start the enhanced sync service when app starts
        next.start();
      }
    });
    
    return MaterialApp(
      title: 'Distributed Todo App',
      home: const TodoHomePage(),
    );
  }
}
```

## Testing the Mesh Network

### 1. Local Testing

1. **Single Device Testing**: Run the app and check that mesh services start without errors
2. **Network Scanning**: Verify that the app can scan the local network
3. **Service Discovery**: Check that mDNS advertising works (when dependencies are added)

### 2. Multi-Device Testing

1. **Two Devices**: Run the app on two devices on the same WiFi network
2. **Peer Discovery**: Verify that devices discover each other
3. **Data Sync**: Create todos on one device and verify they appear on the other
4. **Conflict Resolution**: Create conflicting changes and verify resolution works

### 3. Network Scenarios

1. **Internet + Mesh**: Test with both Firebase and mesh networking active
2. **Mesh Only**: Test with internet disconnected
3. **Network Changes**: Test device joining/leaving the network

## Monitoring and Debugging

### Enable Mesh Logging

Add debug logging to monitor mesh operations:

```dart
// Enable detailed mesh logging
const bool kMeshDebugMode = true;

void meshLog(String message) {
  if (kMeshDebugMode) {
    print('[MESH] $message');
  }
}
```

### Network Diagnostics

Use the mesh status widget to monitor:
- Peer discovery
- Connection status
- Sync operations
- Error conditions

## Performance Considerations

1. **Battery Usage**: Mesh networking will use more battery due to network scanning and connections
2. **Network Traffic**: Monitor data usage, especially on mobile networks
3. **Sync Frequency**: Adjust sync intervals based on user activity
4. **Connection Limits**: Limit concurrent connections to prevent resource exhaustion

## Security Notes

1. **Local Network Only**: Mesh networking only works on local networks
2. **Device Trust**: Consider implementing device verification for production
3. **Data Encryption**: The current implementation has placeholder encryption
4. **Network Isolation**: Ensure mesh traffic stays within the local network

## Next Steps

1. **Add Full mDNS Support**: Install the commented dependencies for proper service discovery
2. **Implement Encryption**: Add real encryption for mesh messages
3. **Add Device Authentication**: Implement device verification and trust management
4. **Performance Optimization**: Optimize for battery life and network usage
5. **UI Enhancements**: Add more detailed mesh network management UI

This integration provides a robust foundation for mesh networking while maintaining compatibility with your existing Firebase sync system. The hybrid approach ensures your app works in all network conditions! 