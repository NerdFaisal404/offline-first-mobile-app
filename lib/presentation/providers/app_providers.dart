import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/datasources/local_database.dart';
import '../../data/datasources/firebase_datasource.dart';
import '../../data/datasources/mesh_datasource.dart';
import '../../data/repositories/todo_repository_impl.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../domain/entities/sync_plan.dart';
import '../../core/utils/conflict_resolver.dart';
import '../../core/services/sync_service.dart' hide SyncResult;
import '../../core/services/mesh_discovery_service.dart';
import '../../core/services/mesh_communication_service.dart';
import '../../core/services/mesh_sync_service.dart';

// Infrastructure providers
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

// Device ID provider (needed for mesh services)
final deviceIdProvider = FutureProvider<String>((ref) async {
  final database = ref.read(localDatabaseProvider);
  final deviceId = await database.getCurrentDeviceId();
  return deviceId ?? 'device-${DateTime.now().millisecondsSinceEpoch}';
});

// Mesh networking service providers
final meshDiscoveryServiceProvider = Provider<MeshDiscoveryService>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown-device';
  return MeshDiscoveryService(
    deviceId: deviceId,
    deviceName: 'Todo Device',
  );
});

final meshCommunicationServiceProvider =
    Provider<MeshCommunicationService>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown-device';
  return MeshCommunicationService(
    deviceId: deviceId,
  );
});

// Mesh data source provider (without sync service to break circular dependency)
final meshDataSourceProvider = Provider<MeshDataSource>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown-device';

  return MeshDataSource(
    deviceId: deviceId,
    syncService: NoOpMeshSyncService(), // Simple no-op implementation
    discoveryService: ref.read(meshDiscoveryServiceProvider),
    communicationService: ref.read(meshCommunicationServiceProvider),
  );
});

// Repository provider using mesh datasource
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepositoryImpl(
    localDatabase: ref.read(localDatabaseProvider),
    meshDataSource: ref.read(meshDataSourceProvider),
    conflictResolver: ref.read(conflictResolverProvider),
  );
});

final meshSyncServiceProvider = Provider<MeshSyncService>((ref) {
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown-device';
  return MeshSyncService(
    deviceId: deviceId,
    todoRepository: ref.read(todoRepositoryProvider),
    conflictResolver: ref.read(conflictResolverProvider),
    discoveryService: ref.read(meshDiscoveryServiceProvider),
    communicationService: ref.read(meshCommunicationServiceProvider),
  );
});

// Stub classes to break circular dependency
class _StubTodoRepository implements TodoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _StubConflictResolver extends ConflictResolver {
  // Minimal stub implementation
}

class _StubMeshDiscoveryService extends MeshDiscoveryService {
  _StubMeshDiscoveryService() : super(deviceId: 'stub', deviceName: 'stub');
}

class _StubMeshCommunicationService extends MeshCommunicationService {
  _StubMeshCommunicationService() : super(deviceId: 'stub');
}

// Simple no-op sync service to break circular dependency
class NoOpMeshSyncService extends MeshSyncService {
  NoOpMeshSyncService()
      : super(
          deviceId: 'noop',
          todoRepository: _StubTodoRepository(),
          conflictResolver: _StubConflictResolver(),
          discoveryService: _StubMeshDiscoveryService(),
          communicationService: _StubMeshCommunicationService(),
        );

  @override
  bool get isRunning => false;

  @override
  List<String> get activeSyncs => [];

  @override
  Future<void> startMeshSync() async {}

  @override
  Future<void> stopMeshSync() async {}

  @override
  Future<SyncResult> syncWithPeer(String peerId) async {
    return SyncResult.failure(
      peerId: peerId,
      errorMessage: 'No-op implementation',
      duration: Duration.zero,
    );
  }

  @override
  Future<List<SyncResult>> syncWithAllPeers() async {
    return [];
  }
}

// Hybrid sync service (supports both Firebase and Mesh)
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    todoRepository: ref.read(todoRepositoryProvider),
    firebaseDataSource: ref.read(firebaseDataSourceProvider),
    localDatabase: ref.read(localDatabaseProvider),
    connectivity: ref.read(connectivityProvider),
  );
});

// Initialize sync callback and mesh networking
final syncInitializerProvider = Provider<void>((ref) {
  final repository = ref.read(todoRepositoryProvider) as TodoRepositoryImpl;
  final syncService = ref.read(syncServiceProvider);

  // Set up the data change callback
  repository.setDataChangeCallback(() {
    // Trigger sync when data changes
    syncService.forcSync().catchError((e) {
      // Handle error silently - sync will retry
      print('Auto-sync failed: $e');
    });
  });

  // Initialize mesh networking
  final meshDataSource = ref.read(meshDataSourceProvider);
  meshDataSource.initialize().catchError((e) {
    print('Mesh initialization failed: $e');
  });
});

// State providers
final todosProvider = StreamProvider((ref) {
  final repository = ref.read(todoRepositoryProvider);
  return repository.watchTodos();
});

final activeTodosProvider = FutureProvider((ref) {
  final repository = ref.read(todoRepositoryProvider);
  return repository.getActiveTodos();
});

final conflictsProvider = StreamProvider((ref) {
  final repository = ref.read(todoRepositoryProvider);
  return repository.watchConflicts();
});

final syncStatusProvider = StreamProvider((ref) {
  final syncService = ref.read(syncServiceProvider);

  return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
    return await syncService.getSyncStatus();
  });
});

// Mesh network status provider
final meshNetworkStatusProvider = StreamProvider((ref) {
  final meshDataSource = ref.read(meshDataSourceProvider);

  return Stream.periodic(const Duration(seconds: 5)).map((_) {
    return meshDataSource.getNetworkStatus();
  });
});

// Mesh comprehensive status provider
final meshComprehensiveStatusProvider = StreamProvider((ref) {
  final meshDataSource = ref.read(meshDataSourceProvider);

  return Stream.periodic(const Duration(seconds: 3)).map((_) {
    return meshDataSource.getComprehensiveStatus();
  });
});

// Discovered peers provider
final discoveredPeersProvider = StreamProvider((ref) {
  final meshDataSource = ref.read(meshDataSourceProvider);

  return Stream.periodic(const Duration(seconds: 2)).map((_) {
    return meshDataSource.getDiscoveredPeers();
  });
});
