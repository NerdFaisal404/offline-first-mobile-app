import 'package:equatable/equatable.dart';
import 'todo.dart';
import 'vector_clock.dart';

/// Represents a conflict between multiple versions of the same todo
class Conflict extends Equatable {
  final String id;
  final String todoId;
  final List<ConflictVersion> versions;
  final DateTime detectedAt;
  final ConflictType type;
  final bool isResolved;
  final String? resolvedBy; // Device ID that resolved the conflict
  final DateTime? resolvedAt;

  const Conflict({
    required this.id,
    required this.todoId,
    required this.versions,
    required this.detectedAt,
    required this.type,
    this.isResolved = false,
    this.resolvedBy,
    this.resolvedAt,
  });

  /// Create a new conflict from conflicting todo versions
  factory Conflict.create({
    required String id,
    required List<Todo> conflictingTodos,
  }) {
    final versions =
        conflictingTodos.map((todo) => ConflictVersion.fromTodo(todo)).toList();

    return Conflict(
      id: id,
      todoId: conflictingTodos.first.id,
      versions: versions,
      detectedAt: DateTime.now(),
      type: _determineConflictType(conflictingTodos),
    );
  }

  /// Determine the type of conflict based on the changes
  static ConflictType _determineConflictType(List<Todo> todos) {
    if (todos.length < 2) return ConflictType.noConflict;

    final hasDeletedVersion = todos.any((todo) => todo.isDeleted);
    final hasNonDeletedVersion = todos.any((todo) => !todo.isDeleted);

    if (hasDeletedVersion && hasNonDeletedVersion) {
      return ConflictType.deleteModify;
    }

    // Check for field-level conflicts
    final firstTodo = todos.first;
    bool hasNameConflict = false;
    bool hasPriceConflict = false;
    bool hasCompletionConflict = false;

    for (final todo in todos.skip(1)) {
      if (todo.name != firstTodo.name) hasNameConflict = true;
      if (todo.price != firstTodo.price) hasPriceConflict = true;
      if (todo.isCompleted != firstTodo.isCompleted)
        hasCompletionConflict = true;
    }

    if (hasNameConflict && hasPriceConflict && hasCompletionConflict) {
      return ConflictType.multipleFields;
    } else if (hasNameConflict && hasPriceConflict) {
      return ConflictType.nameAndPrice;
    } else if (hasNameConflict) {
      return ConflictType.nameOnly;
    } else if (hasPriceConflict) {
      return ConflictType.priceOnly;
    } else if (hasCompletionConflict) {
      return ConflictType.completionOnly;
    }

    return ConflictType.noConflict;
  }

  /// Resolve the conflict by choosing a winning version
  Conflict resolve({
    required String winningVersionId,
    required String resolvingDeviceId,
  }) {
    return copyWith(
      isResolved: true,
      resolvedBy: resolvingDeviceId,
      resolvedAt: DateTime.now(),
    );
  }

  /// Get the version that should be used for automatic resolution
  /// Returns null if manual resolution is required
  ConflictVersion? getAutoResolutionWinner() {
    switch (type) {
      case ConflictType.noConflict:
        return versions.first;

      case ConflictType.completionOnly:
        // Auto-resolve completion conflicts by preferring completed state
        final completedVersion =
            versions.where((v) => v.isCompleted).firstOrNull;
        return completedVersion ?? versions.first;

      case ConflictType.deleteModify:
        // Auto-resolve by preferring deletion (safer option)
        final deletedVersion = versions.where((v) => v.isDeleted).firstOrNull;
        return deletedVersion ?? versions.first;

      default:
        // Manual resolution required for name/price conflicts
        return null;
    }
  }

  /// Get a human-readable description of the conflict
  String getDescription() {
    switch (type) {
      case ConflictType.nameOnly:
        return 'Different names: ${versions.map((v) => '"${v.name}"').join(', ')}';
      case ConflictType.priceOnly:
        return 'Different prices: ${versions.map((v) => '\$${v.price}').join(', ')}';
      case ConflictType.nameAndPrice:
        return 'Different names and prices across versions';
      case ConflictType.completionOnly:
        return 'Different completion states';
      case ConflictType.deleteModify:
        return 'Some versions deleted, others modified';
      case ConflictType.multipleFields:
        return 'Multiple fields differ across versions';
      case ConflictType.noConflict:
        return 'No conflicts detected';
    }
  }

  /// Create a copy with updated fields
  Conflict copyWith({
    String? id,
    String? todoId,
    List<ConflictVersion>? versions,
    DateTime? detectedAt,
    ConflictType? type,
    bool? isResolved,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return Conflict(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      versions: versions ?? this.versions,
      detectedAt: detectedAt ?? this.detectedAt,
      type: type ?? this.type,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        todoId,
        versions,
        detectedAt,
        type,
        isResolved,
        resolvedBy,
        resolvedAt,
      ];
}

/// Represents a single version of a todo in a conflict
class ConflictVersion extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isCompleted;
  final bool isDeleted;
  final VectorClock vectorClock;
  final String deviceId;
  final DateTime updatedAt;

  const ConflictVersion({
    required this.id,
    required this.name,
    required this.price,
    required this.isCompleted,
    required this.isDeleted,
    required this.vectorClock,
    required this.deviceId,
    required this.updatedAt,
  });

  /// Create from a Todo entity
  factory ConflictVersion.fromTodo(Todo todo) {
    return ConflictVersion(
      id: todo.id,
      name: todo.name,
      price: todo.price,
      isCompleted: todo.isCompleted,
      isDeleted: todo.isDeleted,
      vectorClock: todo.vectorClock,
      deviceId: todo.deviceId,
      updatedAt: todo.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        isCompleted,
        isDeleted,
        vectorClock,
        deviceId,
        updatedAt,
      ];
}

/// Types of conflicts that can occur
enum ConflictType {
  noConflict,
  nameOnly,
  priceOnly,
  nameAndPrice,
  completionOnly,
  deleteModify,
  multipleFields,
}

/// Extension to get null-aware first element
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
