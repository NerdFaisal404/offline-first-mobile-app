import 'dart:async';
import 'dart:io';

import '../../domain/entities/todo.dart';
import '../../domain/entities/mesh_peer.dart';
import '../../domain/entities/mesh_message.dart';
import '../../domain/entities/vector_clock.dart';
import '../../domain/entities/sync_plan.dart';
import '../../core/services/mesh_sync_service.dart';
import '../../core/services/mesh_discovery_service.dart';
import '../../core/services/mesh_communication_service.dart';

/// Data source for mesh networking operations
class MeshDataSource {
  final String _deviceId;
  final MeshSyncService _syncService;
  final MeshDiscoveryService _discoveryService;
  final MeshCommunicationService _communicationService;

  // Statistics tracking
  int _totalSyncs = 0;
  int _successfulSyncs = 0;
  int _failedSyncs = 0;
  final List<Duration> _syncDurations = [];
  DateTime? _lastSyncTime;
  int _totalTodosSynced = 0;
  int _totalConflictsResolved = 0;

  // Device info
  String? _deviceName;
  bool _isInitialized = false;

  MeshDataSource({
    required String deviceId,
    required MeshSyncService syncService,
    required MeshDiscoveryService discoveryService,
    required MeshCommunicationService communicationService,
  })  : _deviceId = deviceId,
        _syncService = syncService,
        _discoveryService = discoveryService,
        _communicationService = communicationService {
    _initializeDeviceInfo();
  }

  /// Initialize device info
  Future<void> _initializeDeviceInfo() async {
    try {
      _deviceName = Platform.isAndroid
          ? 'Android Device'
          : Platform.isIOS
              ? 'iOS Device'
              : Platform.isMacOS
                  ? 'macOS Device'
                  : Platform.isWindows
                      ? 'Windows Device'
                      : Platform.isLinux
                          ? 'Linux Device'
                          : 'Unknown Device';
      _isInitialized = true;
    } catch (e) {
      _deviceName = 'Flutter Device';
      _isInitialized = true;
    }
  }

  /// Initialize the mesh data source
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _initializeDeviceInfo();
    }
    await _syncService.startMeshSync();
  }

  /// Stop the mesh data source
  Future<void> stop() async {
    await _syncService.stopMeshSync();
  }

  /// Get all discovered peers
  List<MeshPeer> getDiscoveredPeers() {
    return _discoveryService.discoveredPeers;
  }

  /// Get available (alive) peers
  List<MeshPeer> getAvailablePeers() {
    return _discoveryService.getAvailablePeers();
  }

  /// Get connected peers
  List<String> getConnectedPeers() {
    return _communicationService.connectedPeers;
  }

  /// Check if mesh networking is available
  bool get isMeshAvailable {
    return _syncService.isRunning && getAvailablePeers().isNotEmpty;
  }

  /// Sync todos with a specific peer
  Future<MeshSyncResult> syncWithPeer(String peerId) async {
    final startTime = DateTime.now();
    _totalSyncs++;

    try {
      final result = await _syncService.syncWithPeer(peerId);
      final meshResult = MeshSyncResult.fromSyncResult(result);

      // Track statistics
      final duration = DateTime.now().difference(startTime);
      _syncDurations.add(duration);
      _lastSyncTime = DateTime.now();

      if (meshResult.success) {
        _successfulSyncs++;
        _totalTodosSynced += meshResult.todosSent + meshResult.todosReceived;
        _totalConflictsResolved += meshResult.conflictsDetected;
      } else {
        _failedSyncs++;
      }

      return meshResult;
    } catch (e) {
      _failedSyncs++;
      final duration = DateTime.now().difference(startTime);
      _syncDurations.add(duration);
      _lastSyncTime = DateTime.now();

      return MeshSyncResult.failure(
        peerId: peerId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Sync todos with all available peers
  Future<List<MeshSyncResult>> syncWithAllPeers() async {
    final startTime = DateTime.now();
    final availablePeers = getAvailablePeers();

    try {
      final results = await _syncService.syncWithAllPeers();
      final meshResults =
          results.map((r) => MeshSyncResult.fromSyncResult(r)).toList();

      // Track statistics for all syncs
      final duration = DateTime.now().difference(startTime);
      _syncDurations.add(duration);
      _lastSyncTime = DateTime.now();

      for (final result in meshResults) {
        _totalSyncs++;
        if (result.success) {
          _successfulSyncs++;
          _totalTodosSynced += result.todosSent + result.todosReceived;
          _totalConflictsResolved += result.conflictsDetected;
        } else {
          _failedSyncs++;
        }
      }

      return meshResults;
    } catch (e) {
      // Track failed bulk sync
      _totalSyncs += availablePeers.length;
      _failedSyncs += availablePeers.length;
      final duration = DateTime.now().difference(startTime);
      _syncDurations.add(duration);
      _lastSyncTime = DateTime.now();

      return [
        MeshSyncResult.failure(
          peerId: 'all',
          errorMessage: e.toString(),
        )
      ];
    }
  }

  /// Send a todo to a specific peer
  Future<bool> sendTodoToPeer(String peerId, Todo todo) async {
    try {
      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: peerId,
        type: MessageType.todoData,
        payload: {'todo': todo.toJson()},
      );

      return await _communicationService.sendMessage(peerId, message);
    } catch (e) {
      print('❌ Failed to send todo to peer $peerId: $e');
      return false;
    }
  }

  /// Broadcast a todo to all connected peers
  Future<void> broadcastTodo(Todo todo) async {
    try {
      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: '*', // Broadcast
        type: MessageType.todoData,
        payload: {'todo': todo.toJson()},
      );

      await _communicationService.broadcastMessage(message);
    } catch (e) {
      print('❌ Failed to broadcast todo: $e');
    }
  }

  /// Send todo update to peers
  Future<void> sendTodoUpdate(Todo todo) async {
    try {
      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: '*', // Broadcast
        type: MessageType.todoUpdate,
        payload: {'todo': todo.toJson()},
      );

      await _communicationService.broadcastMessage(message);
    } catch (e) {
      print('❌ Failed to send todo update: $e');
    }
  }

  /// Send todo deletion to peers
  Future<void> sendTodoDelete(Todo todo) async {
    try {
      final deletedTodo = todo.markDeleted(_deviceId);
      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: '*', // Broadcast
        type: MessageType.todoDelete,
        payload: {'todo': deletedTodo.toJson()},
      );

      await _communicationService.broadcastMessage(message);
    } catch (e) {
      print('❌ Failed to send todo deletion: $e');
    }
  }

  /// Request todos from a specific peer
  Future<bool> requestTodosFromPeer(String peerId,
      {VectorClock? sinceVersion}) async {
    try {
      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: peerId,
        type: MessageType.syncRequest,
        payload: {
          'requestType': 'todos',
          'sinceVersion': sinceVersion?.toJson(),
        },
      );

      return await _communicationService.sendMessage(peerId, message);
    } catch (e) {
      print('❌ Failed to request todos from peer $peerId: $e');
      return false;
    }
  }

  /// Get mesh network status
  MeshNetworkStatus getNetworkStatus() {
    final discoveredPeers = getDiscoveredPeers();
    final availablePeers = getAvailablePeers();
    final connectedPeers = getConnectedPeers();
    final activeSyncs = _syncService.activeSyncs;

    return MeshNetworkStatus(
      isActive: _syncService.isRunning,
      discoveredPeersCount: discoveredPeers.length,
      availablePeersCount: availablePeers.length,
      connectedPeersCount: connectedPeers.length,
      activeSyncsCount: activeSyncs.length,
      peers: discoveredPeers,
    );
  }

  /// Watch mesh network status changes
  Stream<MeshNetworkStatus> watchNetworkStatus() {
    return Stream.periodic(
        const Duration(seconds: 5), (_) => getNetworkStatus());
  }

  /// Send heartbeat to connected peers
  Future<void> sendHeartbeat() async {
    try {
      if (!_isInitialized) {
        await _initializeDeviceInfo();
      }

      final message = MeshMessage.create(
        senderId: _deviceId,
        recipientId: '*', // Broadcast
        type: MessageType.heartbeat,
        payload: {
          'timestamp': DateTime.now().toIso8601String(),
          'deviceName': _deviceName ?? 'Unknown Device',
          'deviceId': _deviceId,
        },
      );

      await _communicationService.broadcastMessage(message);
    } catch (e) {
      print('❌ Failed to send heartbeat: $e');
    }
  }

  /// Handle incoming mesh message (called by sync service)
  Future<void> handleIncomingMessage(MeshMessage message) async {
    try {
      print('📥 Received ${message.type} message from ${message.senderId}');

      // Track message statistics
      switch (message.type) {
        case MessageType.todoData:
        case MessageType.todoUpdate:
        case MessageType.todoDelete:
          print('  📄 Todo operation: ${message.type}');
          break;
        case MessageType.syncRequest:
          print('  🔄 Sync request received');
          break;
        case MessageType.syncResponse:
          print('  ✅ Sync response received');
          break;
        case MessageType.heartbeat:
          final deviceName = message.payload['deviceName'] as String?;
          print('  💓 Heartbeat from ${deviceName ?? message.senderId}');
          break;
        case MessageType.peerDiscovery:
          print('  🔍 Peer discovery message');
          break;
        case MessageType.conflictData:
          print('  ⚖️ Conflict resolution message');
          _totalConflictsResolved++;
          break;
        default:
          print('  ❓ Unknown message type: ${message.type}');
      }

      // Update last activity time
      _lastSyncTime = DateTime.now();
    } catch (e) {
      print('❌ Error handling incoming message: $e');
    }
  }

  /// Get sync statistics
  Future<MeshSyncStatistics> getSyncStatistics() async {
    // Calculate average sync duration
    Duration averageDuration = Duration.zero;
    if (_syncDurations.isNotEmpty) {
      final totalMs =
          _syncDurations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
      averageDuration =
          Duration(milliseconds: totalMs ~/ _syncDurations.length);
    }

    return MeshSyncStatistics(
      totalSyncs: _totalSyncs,
      successfulSyncs: _successfulSyncs,
      failedSyncs: _failedSyncs,
      averageSyncDuration: averageDuration,
      lastSyncTime: _lastSyncTime ?? DateTime.now(),
      totalTodosSynced: _totalTodosSynced,
      totalConflictsResolved: _totalConflictsResolved,
    );
  }

  /// Force discovery scan
  Future<List<MeshPeer>> scanForPeers() async {
    return await _discoveryService.scanForPeers();
  }

  /// Connect to a specific peer
  Future<bool> connectToPeer(MeshPeer peer) async {
    return await _communicationService.connectToPeer(peer);
  }

  /// Disconnect from a specific peer
  void disconnectFromPeer(String peerId) {
    _communicationService.disconnectFromPeer(peerId);
  }

  /// Reset sync statistics
  void resetStatistics() {
    _totalSyncs = 0;
    _successfulSyncs = 0;
    _failedSyncs = 0;
    _syncDurations.clear();
    _lastSyncTime = null;
    _totalTodosSynced = 0;
    _totalConflictsResolved = 0;
  }

  /// Get device information
  Map<String, dynamic> getDeviceInfo() {
    return {
      'deviceId': _deviceId,
      'deviceName': _deviceName ?? 'Unknown Device',
      'platform': Platform.operatingSystem,
      'isInitialized': _isInitialized,
    };
  }

  /// Check if the mesh data source is ready for operations
  bool get isReady => _isInitialized && _syncService.isRunning;

  /// Get comprehensive mesh status
  Map<String, dynamic> getComprehensiveStatus() {
    final networkStatus = getNetworkStatus();
    final deviceInfo = getDeviceInfo();

    return {
      'device': deviceInfo,
      'network': {
        'isActive': networkStatus.isActive,
        'isHealthy': networkStatus.isHealthy,
        'discoveredPeers': networkStatus.discoveredPeersCount,
        'availablePeers': networkStatus.availablePeersCount,
        'connectedPeers': networkStatus.connectedPeersCount,
        'activeSyncs': networkStatus.activeSyncsCount,
      },
      'statistics': {
        'totalSyncs': _totalSyncs,
        'successfulSyncs': _successfulSyncs,
        'failedSyncs': _failedSyncs,
        'successRate':
            _totalSyncs > 0 ? (_successfulSyncs / _totalSyncs * 100) : 0,
        'totalTodosSynced': _totalTodosSynced,
        'totalConflictsResolved': _totalConflictsResolved,
        'lastSyncTime': _lastSyncTime?.toIso8601String(),
      },
      'isReady': isReady,
    };
  }
}

/// Result of a mesh sync operation
class MeshSyncResult {
  final String peerId;
  final bool success;
  final int todosSent;
  final int todosReceived;
  final int conflictsDetected;
  final Duration duration;
  final String? errorMessage;

  const MeshSyncResult({
    required this.peerId,
    required this.success,
    required this.todosSent,
    required this.todosReceived,
    required this.conflictsDetected,
    required this.duration,
    this.errorMessage,
  });

  factory MeshSyncResult.fromSyncResult(SyncResult result) {
    return MeshSyncResult(
      peerId: result.peerId,
      success: result.status == SyncStatus.success,
      todosSent: result.todosSent,
      todosReceived: result.todosReceived,
      conflictsDetected: result.conflictsDetected,
      duration: result.duration,
      errorMessage: result.errorMessage,
    );
  }

  factory MeshSyncResult.failure({
    required String peerId,
    required String errorMessage,
  }) {
    return MeshSyncResult(
      peerId: peerId,
      success: false,
      todosSent: 0,
      todosReceived: 0,
      conflictsDetected: 0,
      duration: Duration.zero,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() => 'MeshSyncResult(peer: $peerId, success: $success, '
      'sent: $todosSent, received: $todosReceived)';
}

/// Status of the mesh network
class MeshNetworkStatus {
  final bool isActive;
  final int discoveredPeersCount;
  final int availablePeersCount;
  final int connectedPeersCount;
  final int activeSyncsCount;
  final List<MeshPeer> peers;

  const MeshNetworkStatus({
    required this.isActive,
    required this.discoveredPeersCount,
    required this.availablePeersCount,
    required this.connectedPeersCount,
    required this.activeSyncsCount,
    required this.peers,
  });

  /// Check if mesh networking is healthy
  bool get isHealthy => isActive && availablePeersCount > 0;

  @override
  String toString() => 'MeshNetworkStatus(active: $isActive, '
      'discovered: $discoveredPeersCount, available: $availablePeersCount, '
      'connected: $connectedPeersCount, syncing: $activeSyncsCount)';
}

/// Statistics about mesh synchronization
class MeshSyncStatistics {
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final Duration averageSyncDuration;
  final DateTime lastSyncTime;
  final int totalTodosSynced;
  final int totalConflictsResolved;

  const MeshSyncStatistics({
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.averageSyncDuration,
    required this.lastSyncTime,
    required this.totalTodosSynced,
    required this.totalConflictsResolved,
  });

  /// Calculate success rate as percentage
  double get successRate =>
      totalSyncs > 0 ? (successfulSyncs / totalSyncs) * 100 : 0;

  @override
  String toString() => 'MeshSyncStatistics(total: $totalSyncs, '
      'success: $successfulSyncs, failed: $failedSyncs, '
      'rate: ${successRate.toStringAsFixed(1)}%)';
}
