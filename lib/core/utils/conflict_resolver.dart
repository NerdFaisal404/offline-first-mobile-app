import '../../domain/entities/todo.dart';
import '../../domain/entities/vector_clock.dart';

/// Handles conflict resolution between local and remote todo versions
class ConflictResolver {
  /// Resolve a conflict between local and remote versions of a todo
  ConflictResolution resolveConflict({
    required Todo localVersion,
    required Todo remoteVersion,
    required String currentDeviceId,
  }) {
    // If they're identical, no conflict
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
        // Concurrent changes - need to resolve conflict
        return _resolveConcurrentConflict(
            localVersion, remoteVersion, currentDeviceId);
    }
  }

  /// Resolve concurrent changes using operational transform logic
  ConflictResolution _resolveConcurrentConflict(
    Todo localVersion,
    Todo remoteVersion,
    String currentDeviceId,
  ) {
    // Check if one version is deleted
    if (localVersion.isDeleted != remoteVersion.isDeleted) {
      if (localVersion.isDeleted) {
        return ConflictResolution(
          type: ResolutionType.useLocal, // Prefer deletion
          mergedTodo: localVersion,
        );
      } else {
        return ConflictResolution(
          type: ResolutionType.useRemote, // Prefer deletion
          mergedTodo: remoteVersion,
        );
      }
    }

    // If both are deleted, use the one with higher clock
    if (localVersion.isDeleted && remoteVersion.isDeleted) {
      return _useLatestByClock(localVersion, remoteVersion);
    }

    // Check if only completion status differs (auto-resolvable)
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

    // Check if content fields (name/price) differ - requires manual resolution
    if (_contentFieldsDiffer(localVersion, remoteVersion)) {
      return ConflictResolution(
        type: ResolutionType.requiresManualResolution,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }

    // Default to using the version with the highest vector clock sum
    return _useLatestByClock(localVersion, remoteVersion);
  }

  /// Use the version with the latest vector clock (highest sum)
  ConflictResolution _useLatestByClock(Todo localVersion, Todo remoteVersion) {
    final localClockSum = _getVectorClockSum(localVersion.vectorClock);
    final remoteClockSum = _getVectorClockSum(remoteVersion.vectorClock);

    if (localClockSum >= remoteClockSum) {
      return ConflictResolution(
        type: ResolutionType.useLocal,
        mergedTodo: localVersion,
      );
    } else {
      return ConflictResolution(
        type: ResolutionType.useRemote,
        mergedTodo: remoteVersion,
      );
    }
  }

  /// Check if two todos are identical in all fields
  bool _todosAreIdentical(Todo local, Todo remote) {
    return local.name == remote.name &&
        local.price == remote.price &&
        local.isCompleted == remote.isCompleted &&
        local.isDeleted == remote.isDeleted;
  }

  /// Check if only completion status differs
  bool _onlyCompletionDiffers(Todo local, Todo remote) {
    return local.name == remote.name &&
        local.price == remote.price &&
        local.isDeleted == remote.isDeleted &&
        local.isCompleted != remote.isCompleted;
  }

  /// Check if content fields (name or price) differ
  bool _contentFieldsDiffer(Todo local, Todo remote) {
    return local.name != remote.name || local.price != remote.price;
  }

  /// Get the sum of all clocks in a vector clock
  int _getVectorClockSum(VectorClock vectorClock) {
    return vectorClock.clocks.values.fold(0, (sum, clock) => sum + clock);
  }

  /// Create a manual merge of two conflicting todos
  /// This can be used when user chooses to manually merge conflicts
  Todo createManualMerge({
    required Todo baseTodo,
    required String selectedName,
    required double selectedPrice,
    required bool selectedCompletion,
    required String mergingDeviceId,
  }) {
    final mergedVectorClock = baseTodo.vectorClock.increment(mergingDeviceId);

    return baseTodo.copyWith(
      name: selectedName,
      price: selectedPrice,
      isCompleted: selectedCompletion,
      updatedAt: DateTime.now(),
      vectorClock: mergedVectorClock,
      deviceId: mergingDeviceId,
      version: baseTodo.version + 1,
    );
  }
}

/// Represents the result of conflict resolution
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

/// Types of conflict resolution
enum ResolutionType {
  useLocal,
  useRemote,
  useAutoMerged,
  requiresManualResolution,
}
