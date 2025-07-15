import 'package:equatable/equatable.dart';

/// Represents a peer device in the mesh network
class MeshPeer extends Equatable {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final PeerCapabilities capabilities;
  final PeerStatus status;

  const MeshPeer({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.capabilities,
    required this.status,
  });

  /// Create a copy with updated fields
  MeshPeer copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    int? port,
    DateTime? lastSeen,
    PeerCapabilities? capabilities,
    PeerStatus? status,
  }) {
    return MeshPeer(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      capabilities: capabilities ?? this.capabilities,
      status: status ?? this.status,
    );
  }

  /// Update last seen timestamp
  MeshPeer updateLastSeen() {
    return copyWith(lastSeen: DateTime.now());
  }

  /// Mark peer as connected
  MeshPeer markConnected() {
    return copyWith(status: PeerStatus.connected);
  }

  /// Mark peer as disconnected
  MeshPeer markDisconnected() {
    return copyWith(status: PeerStatus.disconnected);
  }

  /// Check if peer is considered alive based on last seen time
  bool get isAlive {
    final threshold = DateTime.now().subtract(const Duration(minutes: 5));
    return lastSeen.isAfter(threshold);
  }

  /// Get connection endpoint
  String get endpoint => '$ipAddress:$port';

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'ipAddress': ipAddress,
        'port': port,
        'lastSeen': lastSeen.toIso8601String(),
        'capabilities': capabilities.toJson(),
        'status': status.name,
      };

  /// Create from Map for deserialization
  factory MeshPeer.fromJson(Map<String, dynamic> json) {
    return MeshPeer(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      ipAddress: json['ipAddress'],
      port: json['port'],
      lastSeen: DateTime.parse(json['lastSeen']),
      capabilities: PeerCapabilities.fromJson(json['capabilities']),
      status: PeerStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PeerStatus.discovered,
      ),
    );
  }

  @override
  List<Object?> get props => [
        deviceId,
        deviceName,
        ipAddress,
        port,
        lastSeen,
        capabilities,
        status,
      ];

  @override
  String toString() => 'MeshPeer(id: $deviceId, name: $deviceName, '
      'endpoint: $endpoint, status: $status)';
}

/// Represents the capabilities of a peer device
class PeerCapabilities extends Equatable {
  final String appVersion;
  final String platformName;
  final bool supportsEncryption;
  final bool supportsCompression;
  final List<String> supportedSyncStrategies;
  final int maxConcurrentConnections;

  const PeerCapabilities({
    required this.appVersion,
    required this.platformName,
    required this.supportsEncryption,
    required this.supportsCompression,
    required this.supportedSyncStrategies,
    required this.maxConcurrentConnections,
  });

  /// Create default capabilities for this device
  factory PeerCapabilities.defaults() {
    return const PeerCapabilities(
      appVersion: '1.0.0',
      platformName: 'Flutter',
      supportsEncryption: true,
      supportsCompression: true,
      supportedSyncStrategies: [
        'VECTOR_CLOCK_SYNC',
        'INCREMENTAL_SYNC',
        'FULL_SYNC',
      ],
      maxConcurrentConnections: 10,
    );
  }

  /// Check if this peer is compatible with another peer
  bool isCompatibleWith(PeerCapabilities other) {
    // Check version compatibility (major version must match)
    final thisVersion = appVersion.split('.')[0];
    final otherVersion = other.appVersion.split('.')[0];
    if (thisVersion != otherVersion) return false;

    // Check if there's at least one common sync strategy
    final commonStrategies = supportedSyncStrategies
        .toSet()
        .intersection(other.supportedSyncStrategies.toSet());
    return commonStrategies.isNotEmpty;
  }

  /// Get the best sync strategy to use with another peer
  String getBestSyncStrategy(PeerCapabilities other) {
    final commonStrategies = supportedSyncStrategies
        .toSet()
        .intersection(other.supportedSyncStrategies.toSet());

    // Prefer vector clock sync if both support it
    if (commonStrategies.contains('VECTOR_CLOCK_SYNC')) {
      return 'VECTOR_CLOCK_SYNC';
    }
    // Fall back to incremental sync
    if (commonStrategies.contains('INCREMENTAL_SYNC')) {
      return 'INCREMENTAL_SYNC';
    }
    // Last resort: full sync
    if (commonStrategies.contains('FULL_SYNC')) {
      return 'FULL_SYNC';
    }

    throw Exception('No compatible sync strategy found');
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() => {
        'appVersion': appVersion,
        'platformName': platformName,
        'supportsEncryption': supportsEncryption,
        'supportsCompression': supportsCompression,
        'supportedSyncStrategies': supportedSyncStrategies,
        'maxConcurrentConnections': maxConcurrentConnections,
      };

  /// Create from Map for deserialization
  factory PeerCapabilities.fromJson(Map<String, dynamic> json) {
    return PeerCapabilities(
      appVersion: json['appVersion'],
      platformName: json['platformName'],
      supportsEncryption: json['supportsEncryption'],
      supportsCompression: json['supportsCompression'],
      supportedSyncStrategies:
          List<String>.from(json['supportedSyncStrategies']),
      maxConcurrentConnections: json['maxConcurrentConnections'],
    );
  }

  @override
  List<Object?> get props => [
        appVersion,
        platformName,
        supportsEncryption,
        supportsCompression,
        supportedSyncStrategies,
        maxConcurrentConnections,
      ];
}

/// Status of a mesh peer
enum PeerStatus {
  discovered, // Just discovered, not yet connected
  connecting, // Attempting to establish connection
  connected, // Successfully connected and ready for sync
  syncing, // Currently synchronizing data
  disconnected, // Disconnected but may reconnect
  failed, // Connection failed, should retry later
}
