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
    print('🔍 Resolving conflict for todo ${localVersion.id}');
    print(
        '   Local: ${localVersion.name} (\$${localVersion.price}) - ${localVersion.vectorClock}');
    print(
        '   Remote: ${remoteVersion.name} (\$${remoteVersion.price}) - ${remoteVersion.vectorClock}');

    // If they're identical, no conflict
    if (_todosAreIdentical(localVersion, remoteVersion)) {
      print('   ✅ No conflict - todos are identical');
      return ConflictResolution(
        type: ResolutionType.useLocal,
        mergedTodo: localVersion,
      );
    }

    // Check vector clock relationship
    final clockComparison =
        localVersion.vectorClock.compareTo(remoteVersion.vectorClock);

    print('   🕐 Clock comparison: $clockComparison');

    switch (clockComparison) {
      case ComparisonResult.before:
        // Local happened before remote - use remote
        print('   ⬆️ Using remote version (newer)');
        return ConflictResolution(
          type: ResolutionType.useRemote,
          mergedTodo: remoteVersion,
        );

      case ComparisonResult.after:
        // Local happened after remote - use local
        print('   ⬇️ Using local version (newer)');
        return ConflictResolution(
          type: ResolutionType.useLocal,
          mergedTodo: localVersion,
        );

      case ComparisonResult.concurrent:
        // Concurrent changes - need to resolve conflict
        print('   🔄 Concurrent changes detected - resolving...');
        final resolution = _resolveConcurrentConflict(
            localVersion, remoteVersion, currentDeviceId);
        print('   📝 Resolution: ${resolution.type}');
        return resolution;
    }
  }

  /// Resolve concurrent changes using operational transform logic
  ConflictResolution _resolveConcurrentConflict(
    Todo localVersion,
    Todo remoteVersion,
    String currentDeviceId,
  ) {
    print('   🧠 Analyzing concurrent conflict...');

    // Check if one version is deleted
    if (localVersion.isDeleted != remoteVersion.isDeleted) {
      if (localVersion.isDeleted) {
        print('   🗑️ Local deleted - using local');
        return ConflictResolution(
          type: ResolutionType.useLocal, // Prefer deletion
          mergedTodo: localVersion,
        );
      } else {
        print('   🗑️ Remote deleted - using remote');
        return ConflictResolution(
          type: ResolutionType.useRemote, // Prefer deletion
          mergedTodo: remoteVersion,
        );
      }
    }

    // If both are deleted, use the one with higher clock
    if (localVersion.isDeleted && remoteVersion.isDeleted) {
      print('   🗑️ Both deleted - using latest by clock');
      return _useLatestByClock(localVersion, remoteVersion);
    }

    // Try smart field-level merging
    try {
      final mergedTodo =
          _attemptSmartMerge(localVersion, remoteVersion, currentDeviceId);
      print('   🤖 Smart merge successful');
      return ConflictResolution(
        type: ResolutionType.useAutoMerged,
        mergedTodo: mergedTodo,
      );
    } catch (e) {
      print('   ⚠️ Smart merge failed: $e');
    }

    // Check if only completion status differs (auto-resolvable)
    if (_onlyCompletionDiffers(localVersion, remoteVersion)) {
      // Prefer completed state
      final mergedTodo = localVersion.isCompleted || remoteVersion.isCompleted
          ? (localVersion.isCompleted ? localVersion : remoteVersion)
          : localVersion;

      print('   ✅ Auto-resolved completion conflict');
      return ConflictResolution(
        type: ResolutionType.useAutoMerged,
        mergedTodo: mergedTodo,
      );
    }

    // Check if content fields (name/price) differ - requires manual resolution
    if (_contentFieldsDiffer(localVersion, remoteVersion)) {
      print('   👤 Requires manual resolution');
      return ConflictResolution(
        type: ResolutionType.requiresManualResolution,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }

    // Default to using the version with the highest vector clock sum
    print('   🕐 Using latest by clock as fallback');
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

  /// Attempt smart field-level merging
  Todo _attemptSmartMerge(Todo local, Todo remote, String deviceId) {
    // Only attempt smart merge if the changes are compatible
    final nameChanged = local.name != remote.name;
    final priceChanged = local.price != remote.price;
    final completionChanged = local.isCompleted != remote.isCompleted;

    // Smart merge rules
    String mergedName = local.name;
    double mergedPrice = local.price;
    bool mergedCompletion = local.isCompleted;

    // Name merging: prefer longer/more descriptive name
    if (nameChanged) {
      if (local.name.length > remote.name.length * 1.2) {
        mergedName = local.name;
      } else if (remote.name.length > local.name.length * 1.2) {
        mergedName = remote.name;
      } else {
        // Names are similar length - require manual resolution
        throw Exception('Names require manual resolution');
      }
    }

    // Price merging: prefer higher price (assume price increases)
    if (priceChanged) {
      mergedPrice = local.price > remote.price ? local.price : remote.price;
    }

    // Completion merging: prefer completed state
    if (completionChanged) {
      mergedCompletion = local.isCompleted || remote.isCompleted;
    }

    // Create merged todo with incremented vector clock
    final mergedVectorClock =
        local.vectorClock.merge(remote.vectorClock).increment(deviceId);

    return local.copyWith(
      name: mergedName,
      price: mergedPrice,
      isCompleted: mergedCompletion,
      updatedAt: DateTime.now(),
      vectorClock: mergedVectorClock,
      deviceId: deviceId,
      version: local.version + 1,
    );
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
