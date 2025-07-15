import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Represents a message sent between mesh peers
class MeshMessage extends Equatable {
  final String id;
  final String senderId;
  final String recipientId; // '*' for broadcast
  final MessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final int ttl; // Time to live (hops)
  final List<String> routingPath;
  final String checksum;

  const MeshMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.type,
    required this.payload,
    required this.timestamp,
    required this.ttl,
    required this.routingPath,
    required this.checksum,
  });

  /// Create a new message
  factory MeshMessage.create({
    required String senderId,
    required String recipientId,
    required MessageType type,
    required Map<String, dynamic> payload,
    int ttl = 5,
  }) {
    final id = const Uuid().v4();
    final timestamp = DateTime.now();
    final routingPath = <String>[senderId];

    // Calculate checksum
    final messageData = {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl,
    };
    final checksum = _calculateChecksum(messageData);

    return MeshMessage(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      type: type,
      payload: payload,
      timestamp: timestamp,
      ttl: ttl,
      routingPath: routingPath,
      checksum: checksum,
    );
  }

  /// Create a broadcast message
  factory MeshMessage.broadcast({
    required String senderId,
    required MessageType type,
    required Map<String, dynamic> payload,
    int ttl = 3,
  }) {
    return MeshMessage.create(
      senderId: senderId,
      recipientId: '*',
      type: type,
      payload: payload,
      ttl: ttl,
    );
  }

  /// Create a copy with updated routing path
  MeshMessage addToRoutingPath(String nodeId) {
    if (routingPath.contains(nodeId)) {
      // Prevent loops
      return this;
    }

    return copyWith(
      routingPath: [...routingPath, nodeId],
      ttl: ttl - 1,
    );
  }

  /// Create a copy with updated fields
  MeshMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    MessageType? type,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
    int? ttl,
    List<String>? routingPath,
    String? checksum,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      routingPath: routingPath ?? this.routingPath,
      checksum: checksum ?? this.checksum,
    );
  }

  /// Check if message is still valid (TTL > 0)
  bool get isValid => ttl > 0;

  /// Check if message is a broadcast
  bool get isBroadcast => recipientId == '*';

  /// Check if message is for a specific recipient
  bool isForRecipient(String deviceId) {
    return recipientId == deviceId || isBroadcast;
  }

  /// Check if message has been through a specific node
  bool hasPassedThrough(String nodeId) {
    return routingPath.contains(nodeId);
  }

  /// Verify message integrity
  bool verifyChecksum() {
    final messageData = {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl + routingPath.length - 1, // Original TTL
    };
    final expectedChecksum = _calculateChecksum(messageData);
    return checksum == expectedChecksum;
  }

  /// Get message age
  Duration get age => DateTime.now().difference(timestamp);

  /// Check if message is expired (older than 5 minutes)
  bool get isExpired => age > const Duration(minutes: 5);

  /// Calculate checksum for message data
  static String _calculateChecksum(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'recipientId': recipientId,
        'type': type.name,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'ttl': ttl,
        'routingPath': routingPath,
        'checksum': checksum,
      };

  /// Create from Map for deserialization
  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      id: json['id'],
      senderId: json['senderId'],
      recipientId: json['recipientId'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.unknown,
      ),
      payload: Map<String, dynamic>.from(json['payload']),
      timestamp: DateTime.parse(json['timestamp']),
      ttl: json['ttl'],
      routingPath: List<String>.from(json['routingPath']),
      checksum: json['checksum'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        recipientId,
        type,
        payload,
        timestamp,
        ttl,
        routingPath,
        checksum,
      ];

  @override
  String toString() => 'MeshMessage(id: $id, type: $type, '
      'from: $senderId, to: $recipientId, ttl: $ttl)';
}

/// Types of messages that can be sent in the mesh network
enum MessageType {
  // Discovery messages
  presenceAnnouncement,
  peerDiscovery,
  peerResponse,

  // Sync negotiation
  syncRequest,
  syncResponse,
  syncPlan,

  // Data exchange
  todoData,
  todoUpdate,
  todoDelete,
  conflictData,

  // Control messages
  heartbeat,
  goodbye,
  error,

  // Unknown/future message types
  unknown,
}

/// Helper extension for MessageType
extension MessageTypeExtension on MessageType {
  /// Check if message type requires a response
  bool get requiresResponse {
    switch (this) {
      case MessageType.peerDiscovery:
      case MessageType.syncRequest:
      case MessageType.heartbeat:
        return true;
      default:
        return false;
    }
  }

  /// Check if message type is critical (should be retried if failed)
  bool get isCritical {
    switch (this) {
      case MessageType.todoData:
      case MessageType.todoUpdate:
      case MessageType.todoDelete:
      case MessageType.conflictData:
      case MessageType.syncResponse:
        return true;
      default:
        return false;
    }
  }

  /// Get default TTL for this message type
  int get defaultTtl {
    switch (this) {
      case MessageType.presenceAnnouncement:
      case MessageType.heartbeat:
        return 2; // Short range for frequent messages
      case MessageType.peerDiscovery:
      case MessageType.peerResponse:
        return 3; // Medium range for discovery
      case MessageType.todoData:
      case MessageType.todoUpdate:
      case MessageType.todoDelete:
      case MessageType.conflictData:
        return 5; // Long range for important data
      default:
        return 3; // Default medium range
    }
  }
}
