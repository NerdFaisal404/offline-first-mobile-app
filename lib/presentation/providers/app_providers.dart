import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/datasources/local_database.dart';
import '../../data/datasources/firebase_datasource.dart';
import '../../data/repositories/todo_repository_impl.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../core/utils/conflict_resolver.dart';
import '../../core/services/sync_service.dart';

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

// Repository provider
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepositoryImpl(
    localDatabase: ref.read(localDatabaseProvider),
    firebaseDataSource: ref.read(firebaseDataSourceProvider),
    conflictResolver: ref.read(conflictResolverProvider),
  );
});

// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    todoRepository: ref.read(todoRepositoryProvider),
    firebaseDataSource: ref.read(firebaseDataSourceProvider),
    connectivity: ref.read(connectivityProvider),
  );
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

// Device provider
final deviceIdProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(todoRepositoryProvider);
  return await repository.getCurrentDeviceId();
});
