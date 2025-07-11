import 'package:equatable/equatable.dart';
import 'vector_clock.dart';

/// Todo entity with conflict resolution metadata
class Todo extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Conflict resolution metadata
  final VectorClock vectorClock;
  final String deviceId; // Device that last modified this todo
  final int version; // Local version number
  final bool isDeleted; // Soft delete flag
  final String? syncId; // Firebase document ID for syncing

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

  /// Create a new todo with initial values
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

  /// Create a copy with updated fields
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

  /// Update the todo with new data and increment vector clock
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

  /// Mark as deleted (soft delete)
  Todo markDeleted(String deletingDeviceId) {
    return copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
      vectorClock: vectorClock.increment(deletingDeviceId),
      deviceId: deletingDeviceId,
      version: version + 1,
    );
  }

  /// Check if this todo conflicts with another version
  bool conflictsWith(Todo other) {
    return id == other.id &&
        vectorClock.isConcurrentWith(other.vectorClock) &&
        !_isIdentical(other);
  }

  /// Check if two todos are identical in content
  bool _isIdentical(Todo other) {
    return name == other.name &&
        price == other.price &&
        isCompleted == other.isCompleted &&
        isDeleted == other.isDeleted;
  }

  /// Get a summary of changes compared to another version
  TodoChanges getChanges(Todo other) {
    return TodoChanges(
      nameChanged: name != other.name,
      priceChanged: price != other.price,
      completionChanged: isCompleted != other.isCompleted,
      deletionChanged: isDeleted != other.isDeleted,
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'vectorClock': vectorClock.toJson(),
        'deviceId': deviceId,
        'version': version,
        'isDeleted': isDeleted,
        'syncId': syncId,
      };

  /// Create from Map for deserialization
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      isCompleted: json['isCompleted'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      vectorClock: VectorClock.fromJson(json['vectorClock']),
      deviceId: json['deviceId'],
      version: json['version'],
      isDeleted: json['isDeleted'] ?? false,
      syncId: json['syncId'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        isCompleted,
        createdAt,
        updatedAt,
        vectorClock,
        deviceId,
        version,
        isDeleted,
        syncId,
      ];

  @override
  String toString() => 'Todo(id: $id, name: $name, price: $price, '
      'vectorClock: $vectorClock, deviceId: $deviceId, version: $version)';
}

/// Represents changes between two todo versions
class TodoChanges extends Equatable {
  final bool nameChanged;
  final bool priceChanged;
  final bool completionChanged;
  final bool deletionChanged;

  const TodoChanges({
    required this.nameChanged,
    required this.priceChanged,
    required this.completionChanged,
    required this.deletionChanged,
  });

  bool get hasChanges =>
      nameChanged || priceChanged || completionChanged || deletionChanged;

  @override
  List<Object?> get props =>
      [nameChanged, priceChanged, completionChanged, deletionChanged];
}
