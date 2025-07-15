import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/mesh_peer.dart';
import '../../domain/entities/mesh_message.dart';

/// Service responsible for peer-to-peer communication in the mesh network
class MeshCommunicationService {
  final String _deviceId;
  final MessageRouter _router;
  final EncryptionService _encryption;

  ServerSocket? _server;
  final Map<String, Socket> _peerConnections = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  final Set<String> _processedMessages = {};

  final StreamController<MeshMessage> _messageController =
      StreamController<MeshMessage>.broadcast();
  final StreamController<String> _connectionEstablishedController =
      StreamController<String>.broadcast();
  final StreamController<String> _connectionLostController =
      StreamController<String>.broadcast();

  int? _serverPort;
  Timer? _cleanupTimer;

  MeshCommunicationService({
    required String deviceId,
    MessageRouter? router,
    EncryptionService? encryption,
  })  : _deviceId = deviceId,
        _router = router ?? MessageRouter(deviceId),
        _encryption = encryption ?? EncryptionService();

  /// Stream of received messages
  Stream<MeshMessage> get messageStream => _messageController.stream;

  /// Stream of established connections
  Stream<String> get connectionEstablishedStream =>
      _connectionEstablishedController.stream;

  /// Stream of lost connections
  Stream<String> get connectionLostStream => _connectionLostController.stream;

  /// Get current server port
  int? get serverPort => _serverPort;

  /// Get connected peer IDs
  List<String> get connectedPeers => _peerConnections.keys.toList();

  /// Check if connected to a specific peer
  bool isConnectedTo(String peerId) => _peerConnections.containsKey(peerId);

  /// Start the communication server
  Future<void> startServer(int port) async {
    print('🚀 Starting mesh communication server on port $port...');

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _serverPort = port;

      _server!.listen(_handleIncomingConnection);

      // Start cleanup timer
      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _cleanupStaleConnections(),
      );

      print('✅ Mesh communication server started on port $port');
    } catch (e) {
      print('❌ Failed to start server: $e');
      rethrow;
    }
  }

  /// Stop the communication server
  Future<void> stopServer() async {
    print('🛑 Stopping mesh communication server...');

    _cleanupTimer?.cancel();
    await _server?.close();
    _server = null;
    _serverPort = null;

    // Close all peer connections
    for (final connection in _peerConnections.values) {
      connection.destroy();
    }
    _peerConnections.clear();

    // Cancel all subscriptions
    for (final subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();

    _processedMessages.clear();

    print('✅ Mesh communication server stopped');
  }

  /// Connect to a peer
  Future<bool> connectToPeer(MeshPeer peer) async {
    if (peer.deviceId == _deviceId) {
      return false; // Don't connect to ourselves
    }

    if (isConnectedTo(peer.deviceId)) {
      print('Already connected to ${peer.deviceName}');
      return true;
    }

    print('🔗 Connecting to ${peer.deviceName} at ${peer.endpoint}...');

    try {
      final socket = await Socket.connect(
        peer.ipAddress,
        peer.port,
        timeout: const Duration(seconds: 10),
      );

      await _setupPeerConnection(peer.deviceId, socket);

      // Send handshake
      final handshake = MeshMessage.create(
        senderId: _deviceId,
        recipientId: peer.deviceId,
        type: MessageType.peerResponse,
        payload: {
          'handshake': true,
          'deviceName': 'This Device',
          'capabilities': PeerCapabilities.defaults().toJson(),
        },
      );

      await sendMessage(peer.deviceId, handshake);

      print('✅ Connected to ${peer.deviceName}');
      return true;
    } catch (e) {
      print('❌ Failed to connect to ${peer.deviceName}: $e');
      return false;
    }
  }

  /// Send a message to a specific peer
  Future<bool> sendMessage(String peerId, MeshMessage message) async {
    try {
      final connection = _peerConnections[peerId];
      if (connection == null) {
        print('❌ No connection to peer $peerId');
        return false;
      }

      final encryptedMessage = await _encryption.encrypt(message);
      final data = jsonEncode(encryptedMessage.toJson());
      final bytes = utf8.encode(data);
      final length = bytes.length;

      // Send length header first
      connection.add(Uint8List.fromList([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]));

      // Send message data
      connection.add(bytes);

      print('📤 Sent ${message.type} message to $peerId');
      return true;
    } catch (e) {
      print('❌ Failed to send message to $peerId: $e');
      return false;
    }
  }

  /// Broadcast a message to all connected peers
  Future<void> broadcastMessage(MeshMessage message) async {
    print(
        '📡 Broadcasting ${message.type} message to ${_peerConnections.length} peers');

    final futures = <Future<bool>>[];
    for (final peerId in _peerConnections.keys) {
      if (peerId != _deviceId) {
        futures.add(sendMessage(peerId, message));
      }
    }

    await Future.wait(futures);
  }

  /// Disconnect from a peer
  void disconnectFromPeer(String peerId) {
    print('🔌 Disconnecting from peer $peerId');

    final connection = _peerConnections.remove(peerId);
    final subscription = _connectionSubscriptions.remove(peerId);

    subscription?.cancel();
    connection?.destroy();

    _connectionLostController.add(peerId);
  }

  /// Handle incoming connection
  void _handleIncomingConnection(Socket socket) {
    print(
        '📞 Incoming connection from ${socket.remoteAddress}:${socket.remotePort}');

    // For now, use IP:port as temporary peer ID until handshake
    final tempPeerId = '${socket.remoteAddress}:${socket.remotePort}';
    _setupPeerConnection(tempPeerId, socket);
  }

  /// Setup a peer connection
  Future<void> _setupPeerConnection(String peerId, Socket socket) async {
    _peerConnections[peerId] = socket;

    // Handle socket events
    final subscription = socket.listen(
      (data) => _handleIncomingData(peerId, data),
      onDone: () => _handleConnectionClosed(peerId),
      onError: (error) => _handleConnectionError(peerId, error),
    );

    _connectionSubscriptions[peerId] = subscription;
    _connectionEstablishedController.add(peerId);
  }

  /// Handle incoming data from a peer
  void _handleIncomingData(String peerId, Uint8List data) {
    try {
      // In a real implementation, you'd need to handle message framing
      // This is a simplified version
      final jsonString = utf8.decode(data);
      final messageJson = jsonDecode(jsonString) as Map<String, dynamic>;

      final message = MeshMessage.fromJson(messageJson);
      final decryptedMessage = _encryption.decrypt(message);

      onMessageReceived(decryptedMessage);
    } catch (e) {
      print('❌ Error handling incoming data from $peerId: $e');
    }
  }

  /// Handle connection closed
  void _handleConnectionClosed(String peerId) {
    print('🔌 Connection closed: $peerId');
    disconnectFromPeer(peerId);
  }

  /// Handle connection error
  void _handleConnectionError(String peerId, dynamic error) {
    print('❌ Connection error with $peerId: $error');
    disconnectFromPeer(peerId);
  }

  /// Handle received message
  void onMessageReceived(MeshMessage message) {
    // Check if we've already processed this message
    if (_processedMessages.contains(message.id)) {
      return;
    }

    _processedMessages.add(message.id);

    // Verify message integrity
    if (!message.verifyChecksum()) {
      print('❌ Message checksum verification failed: ${message.id}');
      return;
    }

    // Check if message is expired
    if (message.isExpired) {
      print('⏰ Message expired: ${message.id}');
      return;
    }

    print('📥 Received ${message.type} message from ${message.senderId}');

    // Check if message is for us
    if (message.isForRecipient(_deviceId)) {
      _messageController.add(message);
    }

    // Forward message if needed
    if (_router.shouldForward(message)) {
      _forwardMessage(message);
    }
  }

  /// Forward a message to other peers
  Future<void> _forwardMessage(MeshMessage message) async {
    if (!message.isValid) return;

    final forwardingPeers = _router.route(message, connectedPeers);
    for (final peerId in forwardingPeers) {
      if (peerId != message.senderId && !message.hasPassedThrough(peerId)) {
        final forwardedMessage = message.addToRoutingPath(_deviceId);
        await sendMessage(peerId, forwardedMessage);
      }
    }
  }

  /// Maintain connection with a peer
  void _maintainConnection(String peerId) {
    // Send periodic heartbeat
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnectedTo(peerId)) {
        timer.cancel();
        return;
      }

      final heartbeat = MeshMessage.create(
        senderId: _deviceId,
        recipientId: peerId,
        type: MessageType.heartbeat,
        payload: {'timestamp': DateTime.now().toIso8601String()},
      );

      sendMessage(peerId, heartbeat);
    });
  }

  /// Clean up stale connections and processed messages
  void _cleanupStaleConnections() {
    // Remove old processed messages (keep last 1000)
    if (_processedMessages.length > 1000) {
      final toRemove = _processedMessages.length - 1000;
      final iterator = _processedMessages.iterator;
      for (int i = 0; i < toRemove && iterator.moveNext(); i++) {
        _processedMessages.remove(iterator.current);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
    _connectionEstablishedController.close();
    _connectionLostController.close();
  }
}

/// Message router for determining message routing paths
class MessageRouter {
  final String _deviceId;
  final Map<String, List<String>> _routingTable = {};

  MessageRouter(this._deviceId);

  /// Route a message to appropriate peers
  List<String> route(MeshMessage message, List<String> availablePeers) {
    if (message.isBroadcast) {
      // Broadcast to all connected peers except sender
      return availablePeers.where((peer) => peer != message.senderId).toList();
    }

    // For direct messages, try to find optimal path
    final targetId = message.recipientId;
    final optimalPath = getOptimalPath(targetId);

    if (optimalPath.isNotEmpty) {
      return [optimalPath.first];
    }

    // Fallback: forward to all peers (flooding)
    return availablePeers.where((peer) => peer != message.senderId).toList();
  }

  /// Check if message is for this device
  bool isMessageForMe(MeshMessage message) {
    return message.isForRecipient(_deviceId);
  }

  /// Check if message should be forwarded
  bool shouldForward(MeshMessage message) {
    // Don't forward if message is only for us
    if (message.recipientId == _deviceId) return false;

    // Don't forward if TTL expired
    if (!message.isValid) return false;

    // Don't forward if we've already seen this message in routing path
    if (message.hasPassedThrough(_deviceId)) return false;

    return true;
  }

  /// Update routing table with peer information
  void updateRoutingTable(String peerId, String nextHop) {
    _routingTable[peerId] = [nextHop];
  }

  /// Get optimal path to target peer
  List<String> getOptimalPath(String targetId) {
    return _routingTable[targetId] ?? [];
  }
}

/// Simple encryption service for message security
class EncryptionService {
  /// Encrypt a message (simplified - in production use proper encryption)
  Future<MeshMessage> encrypt(MeshMessage message) async {
    // For now, return the message as-is
    // In production, implement proper encryption of the payload
    return message;
  }

  /// Decrypt a message (simplified - in production use proper decryption)
  MeshMessage decrypt(MeshMessage message) {
    // For now, return the message as-is
    // In production, implement proper decryption of the payload
    return message;
  }
}
