import 'dart:async';

import '../../domain/entities/todo.dart';
import '../../domain/entities/mesh_peer.dart';
import '../../domain/entities/mesh_message.dart';
import '../../domain/entities/sync_plan.dart';
import '../../domain/entities/vector_clock.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../core/utils/conflict_resolver.dart';
import 'mesh_discovery_service.dart';
import 'mesh_communication_service.dart';

/// Service that orchestrates data synchronization across the mesh network
class MeshSyncService {
  final String _deviceId;
  final TodoRepository _todoRepository;
  final ConflictResolver _conflictResolver;
  final MeshDiscoveryService _discoveryService;
  final MeshCommunicationService _communicationService;

  final Map<String, DateTime> _lastSyncTimes = {};
  final Map<String, VectorClock> _peerVectorClocks = {};
  final Set<String> _activeSyncs = {};

  Timer? _syncTimer;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _peerDiscoveredSubscription;
  StreamSubscription? _peerLostSubscription;

  bool _isRunning = false;

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 2);
  static const Duration _syncTimeout = Duration(seconds: 30);
  static const int _maxConcurrentSyncs = 3;

  MeshSyncService({
    required String deviceId,
    required TodoRepository todoRepository,
    required ConflictResolver conflictResolver,
    required MeshDiscoveryService discoveryService,
    required MeshCommunicationService communicationService,
  })  : _deviceId = deviceId,
        _todoRepository = todoRepository,
        _conflictResolver = conflictResolver,
        _discoveryService = discoveryService,
        _communicationService = communicationService;

  /// Check if mesh sync is running
  bool get isRunning => _isRunning;

  /// Get currently active sync operations
  List<String> get activeSyncs => _activeSyncs.toList();

  /// Start the mesh synchronization service
  Future<void> startMeshSync() async {
    if (_isRunning) return;

    print('🚀 Starting mesh sync service...');

    try {
      // Start discovery and communication services
      await _discoveryService.start();
      await _communicationService.startServer(45000);

      // Subscribe to messages and peer events
      _subscribeToEvents();

      // Start periodic sync
      _startPeriodicSync();

      _isRunning = true;
      print('✅ Mesh sync service started');
    } catch (e) {
      print('❌ Failed to start mesh sync service: $e');
      rethrow;
    }
  }

  /// Stop the mesh synchronization service
  Future<void> stopMeshSync() async {
    if (!_isRunning) return;

    print('🛑 Stopping mesh sync service...');

    _syncTimer?.cancel();
    await _messageSubscription?.cancel();
    await _peerDiscoveredSubscription?.cancel();
    await _peerLostSubscription?.cancel();

    await _communicationService.stopServer();
    await _discoveryService.stop();

    _activeSyncs.clear();
    _lastSyncTimes.clear();
    _peerVectorClocks.clear();

    _isRunning = false;
    print('✅ Mesh sync service stopped');
  }

  /// Sync with a specific peer
  Future<SyncResult> syncWithPeer(String peerId) async {
    if (_activeSyncs.contains(peerId)) {
      return SyncResult.failure(
        peerId: peerId,
        errorMessage: 'Sync already in progress with this peer',
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    _activeSyncs.add(peerId);

    try {
      print('🔄 Starting sync with peer $peerId');

      // Get available peers
      final availablePeers = _discoveryService.getAvailablePeers();
      final peer = availablePeers.firstWhere(
        (p) => p.deviceId == peerId,
        orElse: () => throw Exception('Peer not found or not available'),
      );

      // Connect to peer if not already connected
      if (!_communicationService.isConnectedTo(peerId)) {
        final connected = await _communicationService.connectToPeer(peer);
        if (!connected) {
          throw Exception('Failed to connect to peer');
        }
      }

      // Negotiate sync plan
      final syncPlan = await _negotiateSync(peerId);
      if (!syncPlan.hasWork) {
        print('✅ No sync needed with peer $peerId');
        return SyncResult.success(
          peerId: peerId,
          todosSent: 0,
          todosReceived: 0,
          conflictsDetected: 0,
          duration: DateTime.now().difference(startTime),
        );
      }

      // Execute sync plan
      final result = await _executeSync(syncPlan);

      // Update last sync time
      _lastSyncTimes[peerId] = DateTime.now();

      print('✅ Sync completed with peer $peerId');
      return result;
    } catch (e) {
      print('❌ Sync failed with peer $peerId: $e');
      return SyncResult.failure(
        peerId: peerId,
        errorMessage: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    } finally {
      _activeSyncs.remove(peerId);
    }
  }

  /// Sync with all available peers
  Future<List<SyncResult>> syncWithAllPeers() async {
    final availablePeers = _discoveryService.getAvailablePeers();
    final results = <SyncResult>[];

    print('🔄 Syncing with ${availablePeers.length} available peers');

    // Limit concurrent syncs
    final peersToSync = availablePeers
        .where((peer) => !_activeSyncs.contains(peer.deviceId))
        .take(_maxConcurrentSyncs)
        .toList();

    final futures = peersToSync.map((peer) => syncWithPeer(peer.deviceId));
    results.addAll(await Future.wait(futures));

    return results;
  }

  /// Handle incoming sync request
  Future<SyncResponse> handleSyncRequest(MeshMessage request) async {
    try {
      print('📥 Handling sync request from ${request.senderId}');

      final payload = request.payload;
      final lastKnownClock = payload['lastKnownClock'] != null
          ? VectorClock.fromJson(payload['lastKnownClock'])
          : null;

      // Determine what todos to send
      final todosToSend = await _getTodosToSend(lastKnownClock);
      final currentClock = await _getCurrentVectorClock();

      // Create sync plan
      final syncPlan = SyncPlan.vectorClockSync(
        peerId: request.senderId,
        todosToSend: todosToSend.map((t) => t.id).toList(),
        todosToRequest: [], // Will be filled by requester
        lastKnownClock: lastKnownClock ?? VectorClock.empty(),
        isInitiator: false,
      );

      // Send sync response
      final response = MeshMessage.create(
        senderId: _deviceId,
        recipientId: request.senderId,
        type: MessageType.syncResponse,
        payload: {
          'syncPlan': syncPlan.toJson(),
          'currentClock': currentClock.toJson(),
          'todosCount': todosToSend.length,
        },
      );

      await _communicationService.sendMessage(request.senderId, response);

      return SyncResponse.success(syncPlan);
    } catch (e) {
      print('❌ Failed to handle sync request: $e');
      return SyncResponse.failure(e.toString());
    }
  }

  /// Handle incoming sync response
  Future<void> handleSyncResponse(MeshMessage response) async {
    try {
      print('📥 Handling sync response from ${response.senderId}');

      final payload = response.payload;
      final syncPlan = SyncPlan.fromJson(payload['syncPlan']);
      final peerClock = VectorClock.fromJson(payload['currentClock']);

      // Update peer's vector clock
      _peerVectorClocks[response.senderId] = peerClock;

      // Execute the sync plan
      await _executeSync(syncPlan);
    } catch (e) {
      print('❌ Failed to handle sync response: $e');
    }
  }

  /// Subscribe to mesh events
  void _subscribeToEvents() {
    // Subscribe to incoming messages
    _messageSubscription =
        _communicationService.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });

    // Subscribe to peer discovery
    _peerDiscoveredSubscription =
        _discoveryService.peerDiscoveredStream.listen((peer) {
      _handlePeerDiscovered(peer);
    });

    // Subscribe to peer loss
    _peerLostSubscription = _discoveryService.peerLostStream.listen((peerId) {
      _handlePeerLost(peerId);
    });
  }

  /// Handle incoming mesh message
  Future<void> _handleIncomingMessage(MeshMessage message) async {
    switch (message.type) {
      case MessageType.syncRequest:
        await handleSyncRequest(message);
        break;
      case MessageType.syncResponse:
        await handleSyncResponse(message);
        break;
      case MessageType.todoData:
        await _handleTodoData(message);
        break;
      case MessageType.todoUpdate:
        await _handleTodoUpdate(message);
        break;
      case MessageType.todoDelete:
        await _handleTodoDelete(message);
        break;
      case MessageType.conflictData:
        await _handleConflictData(message);
        break;
      default:
        // Ignore other message types
        break;
    }
  }

  /// Handle peer discovered
  void _handlePeerDiscovered(MeshPeer peer) {
    print('👋 Peer discovered: ${peer.deviceName}');

    // Optionally trigger immediate sync with new peer
    Timer(const Duration(seconds: 5), () {
      if (_isRunning && !_activeSyncs.contains(peer.deviceId)) {
        syncWithPeer(peer.deviceId);
      }
    });
  }

  /// Handle peer lost
  void _handlePeerLost(String peerId) {
    print('👋 Peer lost: $peerId');

    // Clean up peer data
    _lastSyncTimes.remove(peerId);
    _peerVectorClocks.remove(peerId);
    _activeSyncs.remove(peerId);
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_isRunning) {
        _performPeriodicSync();
      }
    });
  }

  /// Perform periodic sync
  Future<void> _performPeriodicSync() async {
    try {
      final availablePeers = _discoveryService.getAvailablePeers();
      if (availablePeers.isEmpty) return;

      // Find peers that need syncing
      final peersToSync = <MeshPeer>[];
      for (final peer in availablePeers) {
        final lastSync = _lastSyncTimes[peer.deviceId];
        if (lastSync == null ||
            DateTime.now().difference(lastSync) > _syncInterval) {
          peersToSync.add(peer);
        }
      }

      if (peersToSync.isNotEmpty) {
        print('⏰ Periodic sync with ${peersToSync.length} peers');
        await syncWithAllPeers();
      }
    } catch (e) {
      print('❌ Error in periodic sync: $e');
    }
  }

  /// Negotiate sync plan with a peer
  Future<SyncPlan> _negotiateSync(String peerId) async {
    final currentClock = await _getCurrentVectorClock();
    final lastKnownClock = _peerVectorClocks[peerId];

    // Send sync request
    final request = MeshMessage.create(
      senderId: _deviceId,
      recipientId: peerId,
      type: MessageType.syncRequest,
      payload: {
        'lastKnownClock': lastKnownClock?.toJson(),
        'currentClock': currentClock.toJson(),
      },
    );

    await _communicationService.sendMessage(peerId, request);

    // For now, return a basic sync plan
    // In a real implementation, you'd wait for the response
    final todosToSend = await _getTodosToSend(lastKnownClock);

    return SyncPlan.vectorClockSync(
      peerId: peerId,
      todosToSend: todosToSend.map((t) => t.id).toList(),
      todosToRequest: [],
      lastKnownClock: lastKnownClock ?? VectorClock.empty(),
      isInitiator: true,
    );
  }

  /// Execute a sync plan
  Future<SyncResult> _executeSync(SyncPlan plan) async {
    final startTime = DateTime.now();
    int todosSent = 0;
    int todosReceived = 0;
    int conflictsDetected = 0;

    try {
      // Send todos to peer
      for (final todoId in plan.todosToSend) {
        final todo = await _todoRepository.getTodoById(todoId);
        if (todo != null) {
          final message = MeshMessage.create(
            senderId: _deviceId,
            recipientId: plan.peerId,
            type: MessageType.todoData,
            payload: {'todo': todo.toJson()},
          );

          await _communicationService.sendMessage(plan.peerId, message);
          todosSent++;
        }
      }

      // Request todos from peer
      if (plan.todosToRequest.isNotEmpty) {
        final message = MeshMessage.create(
          senderId: _deviceId,
          recipientId: plan.peerId,
          type: MessageType.syncRequest,
          payload: {
            'requestedTodos': plan.todosToRequest,
          },
        );

        await _communicationService.sendMessage(plan.peerId, message);
      }

      return SyncResult.success(
        peerId: plan.peerId,
        todosSent: todosSent,
        todosReceived: todosReceived,
        conflictsDetected: conflictsDetected,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return SyncResult.failure(
        peerId: plan.peerId,
        errorMessage: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Handle conflicts detected during sync
  Future<void> _handleConflicts(List<Todo> conflictingTodos) async {
    for (final todo in conflictingTodos) {
      try {
        final localTodo = await _todoRepository.getTodoById(todo.id);
        if (localTodo != null) {
          final resolution = _conflictResolver.resolveConflict(
            localVersion: localTodo,
            remoteVersion: todo,
            currentDeviceId: _deviceId,
          );

          if (resolution.type == ResolutionType.useAutoMerged ||
              resolution.type == ResolutionType.useLocal ||
              resolution.type == ResolutionType.useRemote) {
            await _todoRepository.updateTodo(resolution.mergedTodo!);
          } else {
            // Manual resolution required - create conflict record
            // This would integrate with your existing conflict system
          }
        }
      } catch (e) {
        print('❌ Error handling conflict for todo ${todo.id}: $e');
      }
    }
  }

  /// Get todos to send based on vector clock comparison
  Future<List<Todo>> _getTodosToSend(VectorClock? peerClock) async {
    final allTodos = await _todoRepository.getAllTodos();

    if (peerClock == null) {
      // Send all todos if we don't know peer's state
      return allTodos;
    }

    // Send todos that are newer than peer's known state
    return allTodos.where((todo) {
      return todo.vectorClock.compareTo(peerClock) == ComparisonResult.after ||
          todo.vectorClock.isConcurrentWith(peerClock);
    }).toList();
  }

  /// Get current device's vector clock state
  Future<VectorClock> _getCurrentVectorClock() async {
    final allTodos = await _todoRepository.getAllTodos();

    if (allTodos.isEmpty) {
      return VectorClock.forDevice(_deviceId, 0);
    }

    // Merge all todo vector clocks to get current state
    VectorClock currentClock = allTodos.first.vectorClock;
    for (int i = 1; i < allTodos.length; i++) {
      currentClock = currentClock.merge(allTodos[i].vectorClock);
    }

    return currentClock;
  }

  /// Handle incoming todo data
  Future<void> _handleTodoData(MeshMessage message) async {
    try {
      final todoData = message.payload['todo'] as Map<String, dynamic>;
      final todo = Todo.fromJson(todoData);

      // Check if we already have this todo
      final existingTodo = await _todoRepository.getTodoById(todo.id);

      if (existingTodo == null) {
        // New todo - add it
        await _todoRepository.createTodo(todo);
      } else {
        // Check for conflicts
        if (todo.conflictsWith(existingTodo)) {
          final resolution = _conflictResolver.resolveConflict(
            localVersion: existingTodo,
            remoteVersion: todo,
            currentDeviceId: _deviceId,
          );

          if (resolution.mergedTodo != null) {
            await _todoRepository.updateTodo(resolution.mergedTodo!);
          }
        } else {
          // No conflict - use the newer version
          final comparison =
              todo.vectorClock.compareTo(existingTodo.vectorClock);
          if (comparison == ComparisonResult.after) {
            await _todoRepository.updateTodo(todo);
          }
        }
      }
    } catch (e) {
      print('❌ Error handling todo data: $e');
    }
  }

  /// Handle todo update
  Future<void> _handleTodoUpdate(MeshMessage message) async {
    await _handleTodoData(message); // Same logic for now
  }

  /// Handle todo deletion
  Future<void> _handleTodoDelete(MeshMessage message) async {
    try {
      final todoData = message.payload['todo'] as Map<String, dynamic>;
      final todo = Todo.fromJson(todoData);

      if (todo.isDeleted) {
        final existingTodo = await _todoRepository.getTodoById(todo.id);
        if (existingTodo != null && !existingTodo.isDeleted) {
          // Mark as deleted locally
          await _todoRepository.deleteTodo(todo.id);
        }
      }
    } catch (e) {
      print('❌ Error handling todo deletion: $e');
    }
  }

  /// Handle conflict data
  Future<void> _handleConflictData(MeshMessage message) async {
    // Handle conflict resolution data from other peers
    // This would integrate with your existing conflict resolution system
  }
}

/// Response to a sync request
class SyncResponse {
  final bool success;
  final SyncPlan? plan;
  final String? errorMessage;

  const SyncResponse._({
    required this.success,
    this.plan,
    this.errorMessage,
  });

  factory SyncResponse.success(SyncPlan plan) {
    return SyncResponse._(success: true, plan: plan);
  }

  factory SyncResponse.failure(String errorMessage) {
    return SyncResponse._(success: false, errorMessage: errorMessage);
  }
}
