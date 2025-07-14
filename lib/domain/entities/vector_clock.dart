import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Vector clock implementation for tracking causal ordering in distributed systems
/// Each device maintains a logical clock that increments with each operation
class VectorClock extends Equatable {
  final Map<String, int> _clocks;

  const VectorClock(this._clocks);

  /// Create an empty vector clock
  const VectorClock.empty() : _clocks = const {};

  /// Create a vector clock with a single device
  VectorClock.forDevice(String deviceId, int clock)
      : _clocks = {deviceId: clock};

  /// Get the clock value for a specific device
  int clockFor(String deviceId) => _clocks[deviceId] ?? 0;

  /// Get all device IDs in this vector clock
  Set<String> get deviceIds => _clocks.keys.toSet();

  /// Get a copy of all clocks
  Map<String, int> get clocks => Map.unmodifiable(_clocks);

  /// Increment the clock for a specific device
  VectorClock increment(String deviceId) {
    final newClocks = Map<String, int>.from(_clocks);
    newClocks[deviceId] = (newClocks[deviceId] ?? 0) + 1;
    return VectorClock(newClocks);
  }

  /// Merge this vector clock with another (taking maximum of each device clock)
  VectorClock merge(VectorClock other) {
    final newClocks = Map<String, int>.from(_clocks);

    for (final entry in other._clocks.entries) {
      final deviceId = entry.key;
      final otherClock = entry.value;
      newClocks[deviceId] = math.max(newClocks[deviceId] ?? 0, otherClock);
    }

    return VectorClock(newClocks);
  }

  /// Compare two vector clocks for causal ordering
  /// Returns:
  /// - ComparisonResult.before: this happened before other
  /// - ComparisonResult.after: this happened after other
  /// - ComparisonResult.concurrent: concurrent/conflicting events
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

    // If clocks are exactly equal, treat as concurrent (no conflict)
    if (areEqual) {
      return ComparisonResult.concurrent;
    }
    // If this clock is less than or equal to other (and not equal), this happened before
    else if (thisLessOrEqual) {
      return ComparisonResult.before;
    }
    // If other clock is less than or equal to this (and not equal), this happened after
    else if (otherLessOrEqual) {
      return ComparisonResult.after;
    }
    // Neither dominates the other - truly concurrent
    else {
      return ComparisonResult.concurrent;
    }
  }

  /// Check if this vector clock happened before another
  bool happensBefore(VectorClock other) {
    return compareTo(other) == ComparisonResult.before;
  }

  /// Check if this vector clock is concurrent with another
  bool isConcurrentWith(VectorClock other) {
    return compareTo(other) == ComparisonResult.concurrent;
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'clocks': _clocks,
      };

  /// Create from Map for deserialization
  factory VectorClock.fromJson(Map<String, dynamic> json) {
    final clocks = Map<String, int>.from(json['clocks'] ?? {});
    return VectorClock(clocks);
  }

  @override
  List<Object?> get props => [_clocks];

  @override
  String toString() => 'VectorClock($_clocks)';
}

enum ComparisonResult {
  before,
  after,
  concurrent,
}
