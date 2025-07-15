import 'package:equatable/equatable.dart';
import 'vector_clock.dart';

/// Represents a plan for synchronizing data between two peers
class SyncPlan extends Equatable {
  final String peerId;
  final SyncStrategy strategy;
  final List<String> todosToSend;
  final List<String> todosToRequest;
  final DateTime? lastSyncTime;
  final VectorClock? lastKnownClock;
  final bool isInitiator;
  final SyncPriority priority;

  const SyncPlan({
    required this.peerId,
    required this.strategy,
    required this.todosToSend,
    required this.todosToRequest,
    this.lastSyncTime,
    this.lastKnownClock,
    required this.isInitiator,
    required this.priority,
  });

  /// Create a full sync plan (sync all data)
  factory SyncPlan.fullSync({
    required String peerId,
    required List<String> todosToSend,
    required bool isInitiator,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncPlan(
      peerId: peerId,
      strategy: SyncStrategy.fullSync,
      todosToSend: todosToSend,
      todosToRequest: [], // Will request all from peer
      isInitiator: isInitiator,
      priority: priority,
    );
  }

  /// Create an incremental sync plan (sync only changes since last sync)
  factory SyncPlan.incrementalSync({
    required String peerId,
    required List<String> todosToSend,
    required List<String> todosToRequest,
    required DateTime lastSyncTime,
    required bool isInitiator,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncPlan(
      peerId: peerId,
      strategy: SyncStrategy.incrementalSync,
      todosToSend: todosToSend,
      todosToRequest: todosToRequest,
      lastSyncTime: lastSyncTime,
      isInitiator: isInitiator,
      priority: priority,
    );
  }

  /// Create a vector clock based sync plan
  factory SyncPlan.vectorClockSync({
    required String peerId,
    required List<String> todosToSend,
    required List<String> todosToRequest,
    required VectorClock lastKnownClock,
    required bool isInitiator,
    SyncPriority priority = SyncPriority.normal,
  }) {
    return SyncPlan(
      peerId: peerId,
      strategy: SyncStrategy.vectorClockSync,
      todosToSend: todosToSend,
      todosToRequest: todosToRequest,
      lastKnownClock: lastKnownClock,
      isInitiator: isInitiator,
      priority: priority,
    );
  }

  /// Create a copy with updated fields
  SyncPlan copyWith({
    String? peerId,
    SyncStrategy? strategy,
    List<String>? todosToSend,
    List<String>? todosToRequest,
    DateTime? lastSyncTime,
    VectorClock? lastKnownClock,
    bool? isInitiator,
    SyncPriority? priority,
  }) {
    return SyncPlan(
      peerId: peerId ?? this.peerId,
      strategy: strategy ?? this.strategy,
      todosToSend: todosToSend ?? this.todosToSend,
      todosToRequest: todosToRequest ?? this.todosToRequest,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastKnownClock: lastKnownClock ?? this.lastKnownClock,
      isInitiator: isInitiator ?? this.isInitiator,
      priority: priority ?? this.priority,
    );
  }

  /// Check if this sync plan has any work to do
  bool get hasWork => todosToSend.isNotEmpty || todosToRequest.isNotEmpty;

  /// Get the estimated size/complexity of this sync
  int get estimatedComplexity {
    return todosToSend.length + todosToRequest.length;
  }

  /// Check if this is a full sync
  bool get isFullSync => strategy == SyncStrategy.fullSync;

  /// Check if this uses vector clocks
  bool get usesVectorClocks => strategy == SyncStrategy.vectorClockSync;

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'strategy': strategy.name,
        'todosToSend': todosToSend,
        'todosToRequest': todosToRequest,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'lastKnownClock': lastKnownClock?.toJson(),
        'isInitiator': isInitiator,
        'priority': priority.name,
      };

  /// Create from Map for deserialization
  factory SyncPlan.fromJson(Map<String, dynamic> json) {
    return SyncPlan(
      peerId: json['peerId'],
      strategy: SyncStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => SyncStrategy.fullSync,
      ),
      todosToSend: List<String>.from(json['todosToSend']),
      todosToRequest: List<String>.from(json['todosToRequest']),
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'])
          : null,
      lastKnownClock: json['lastKnownClock'] != null
          ? VectorClock.fromJson(json['lastKnownClock'])
          : null,
      isInitiator: json['isInitiator'],
      priority: SyncPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => SyncPriority.normal,
      ),
    );
  }

  @override
  List<Object?> get props => [
        peerId,
        strategy,
        todosToSend,
        todosToRequest,
        lastSyncTime,
        lastKnownClock,
        isInitiator,
        priority,
      ];

  @override
  String toString() => 'SyncPlan(peer: $peerId, strategy: $strategy, '
      'send: ${todosToSend.length}, request: ${todosToRequest.length})';
}

/// Strategies for synchronizing data between peers
enum SyncStrategy {
  /// Sync all data (full synchronization)
  fullSync,

  /// Sync only changes since last sync (time-based)
  incrementalSync,

  /// Sync based on vector clock comparisons
  vectorClockSync,

  /// Use gossip protocol for eventual consistency
  gossipProtocol,
}

/// Priority levels for sync operations
enum SyncPriority {
  /// Low priority - can be delayed
  low,

  /// Normal priority - standard sync
  normal,

  /// High priority - important changes
  high,

  /// Critical priority - immediate sync required
  critical,
}

/// Result of a sync operation
class SyncResult extends Equatable {
  final String peerId;
  final SyncStatus status;
  final int todosSent;
  final int todosReceived;
  final int conflictsDetected;
  final Duration duration;
  final String? errorMessage;
  final DateTime completedAt;

  const SyncResult({
    required this.peerId,
    required this.status,
    required this.todosSent,
    required this.todosReceived,
    required this.conflictsDetected,
    required this.duration,
    this.errorMessage,
    required this.completedAt,
  });

  /// Create a successful sync result
  factory SyncResult.success({
    required String peerId,
    required int todosSent,
    required int todosReceived,
    required int conflictsDetected,
    required Duration duration,
  }) {
    return SyncResult(
      peerId: peerId,
      status: SyncStatus.success,
      todosSent: todosSent,
      todosReceived: todosReceived,
      conflictsDetected: conflictsDetected,
      duration: duration,
      completedAt: DateTime.now(),
    );
  }

  /// Create a failed sync result
  factory SyncResult.failure({
    required String peerId,
    required String errorMessage,
    required Duration duration,
  }) {
    return SyncResult(
      peerId: peerId,
      status: SyncStatus.failed,
      todosSent: 0,
      todosReceived: 0,
      conflictsDetected: 0,
      duration: duration,
      errorMessage: errorMessage,
      completedAt: DateTime.now(),
    );
  }

  /// Check if sync was successful
  bool get isSuccess => status == SyncStatus.success;

  /// Check if sync had any activity
  bool get hadActivity => todosSent > 0 || todosReceived > 0;

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'status': status.name,
        'todosSent': todosSent,
        'todosReceived': todosReceived,
        'conflictsDetected': conflictsDetected,
        'duration': duration.inMilliseconds,
        'errorMessage': errorMessage,
        'completedAt': completedAt.toIso8601String(),
      };

  /// Create from Map for deserialization
  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      peerId: json['peerId'],
      status: SyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncStatus.failed,
      ),
      todosSent: json['todosSent'],
      todosReceived: json['todosReceived'],
      conflictsDetected: json['conflictsDetected'],
      duration: Duration(milliseconds: json['duration']),
      errorMessage: json['errorMessage'],
      completedAt: DateTime.parse(json['completedAt']),
    );
  }

  @override
  List<Object?> get props => [
        peerId,
        status,
        todosSent,
        todosReceived,
        conflictsDetected,
        duration,
        errorMessage,
        completedAt,
      ];

  @override
  String toString() => 'SyncResult(peer: $peerId, status: $status, '
      'sent: $todosSent, received: $todosReceived, conflicts: $conflictsDetected)';
}

/// Status of a sync operation
enum SyncStatus {
  pending,
  inProgress,
  success,
  failed,
  cancelled,
}
