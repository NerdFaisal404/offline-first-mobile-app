import 'dart:async';
import 'dart:io';
import 'dart:math';
// TODO: Add these dependencies to pubspec.yaml when ready to enable mDNS
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:nsd/nsd.dart';

import '../../domain/entities/mesh_peer.dart';

/// Service responsible for discovering mesh peers on the local network
class MeshDiscoveryService {
  static const String _serviceType = '_todo_mesh._tcp';
  static const String _serviceName = 'TodoMeshNode';
  static const int _basePort = 45000;
  static const Duration _discoveryInterval = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  final String _deviceId;
  final String _deviceName;
  final NetworkScanner _scanner;

  Timer? _discoveryTimer;
  Timer? _heartbeatTimer;
  dynamic _serviceRegistration; // Registration? when mDNS is available
  dynamic _serviceDiscovery; // Discovery? when mDNS is available

  final Map<String, MeshPeer> _discoveredPeers = {};
  final StreamController<List<MeshPeer>> _peersController =
      StreamController<List<MeshPeer>>.broadcast();
  final StreamController<MeshPeer> _peerDiscoveredController =
      StreamController<MeshPeer>.broadcast();
  final StreamController<String> _peerLostController =
      StreamController<String>.broadcast();

  String? _localIP;
  int _localPort = _basePort;

  MeshDiscoveryService({
    required String deviceId,
    required String deviceName,
    NetworkScanner? scanner,
  })  : _deviceId = deviceId,
        _deviceName = deviceName,
        _scanner = scanner ?? NetworkScanner();

  /// Stream of all discovered peers
  Stream<List<MeshPeer>> get peersStream => _peersController.stream;

  /// Stream of newly discovered peers
  Stream<MeshPeer> get peerDiscoveredStream => _peerDiscoveredController.stream;

  /// Stream of lost peer device IDs
  Stream<String> get peerLostStream => _peerLostController.stream;

  /// Get current list of discovered peers
  List<MeshPeer> get discoveredPeers => _discoveredPeers.values.toList();

  /// Get available (alive) peers
  List<MeshPeer> getAvailablePeers() {
    return _discoveredPeers.values.where((peer) => peer.isAlive).toList();
  }

  /// Start the discovery service
  Future<void> start() async {
    print('🔍 Starting mesh discovery service...');

    try {
      // Get local network information
      await _initializeNetworkInfo();

      // Start advertising this device
      await _startAdvertising();

      // Start discovering other devices
      await _startDiscovering();

      // Start periodic discovery and heartbeat
      _startPeriodicDiscovery();
      _startHeartbeat();

      print('✅ Mesh discovery service started on $_localIP:$_localPort');
    } catch (e) {
      print('❌ Failed to start mesh discovery service: $e');
      rethrow;
    }
  }

  /// Stop the discovery service
  Future<void> stop() async {
    print('🛑 Stopping mesh discovery service...');

    _discoveryTimer?.cancel();
    _heartbeatTimer?.cancel();

    // TODO: Uncomment when mDNS is available
    // await _serviceRegistration?.unregister();
    // await _serviceDiscovery?.stop();

    _serviceRegistration = null;
    _serviceDiscovery = null;

    _discoveredPeers.clear();
    _peersController.add([]);

    print('✅ Mesh discovery service stopped');
  }

  /// Force a discovery scan
  Future<List<MeshPeer>> scanForPeers() async {
    print('🔍 Scanning for mesh peers...');

    try {
      // Scan local network for potential peers
      final hosts = await _scanner.scanLocalNetwork();
      final discoveredPeers = <MeshPeer>[];

      for (final ip in hosts) {
        try {
          // Try to probe the mesh port
          if (await _scanner.probePort(ip, _basePort)) {
            // Found a potential peer, try to get device info
            final peer = await _probePeer(ip, _basePort);
            if (peer != null) {
              discoveredPeers.add(peer);
            }
          }
        } catch (e) {
          // Ignore individual host errors
          continue;
        }
      }

      print('📱 Found ${discoveredPeers.length} mesh peers');
      return discoveredPeers;
    } catch (e) {
      print('❌ Error scanning for peers: $e');
      return [];
    }
  }

  /// Broadcast presence to the network
  Future<void> broadcastPresence() async {
    // This is handled by mDNS service registration
    // but we can also implement a custom UDP broadcast if needed
    print('📡 Broadcasting presence via mDNS...');
  }

  /// Handle peer discovered event
  void onPeerDiscovered(MeshPeer peer) {
    print('👋 Discovered peer: ${peer.deviceName} (${peer.ipAddress})');

    final existingPeer = _discoveredPeers[peer.deviceId];
    if (existingPeer == null) {
      _discoveredPeers[peer.deviceId] = peer;
      _peerDiscoveredController.add(peer);
    } else {
      // Update existing peer
      _discoveredPeers[peer.deviceId] = existingPeer.updateLastSeen();
    }

    _peersController.add(discoveredPeers);
  }

  /// Handle peer lost event
  void onPeerLost(String deviceId) {
    print('👋 Lost peer: $deviceId');

    if (_discoveredPeers.containsKey(deviceId)) {
      _discoveredPeers.remove(deviceId);
      _peerLostController.add(deviceId);
      _peersController.add(discoveredPeers);
    }
  }

  /// Initialize network information
  Future<void> _initializeNetworkInfo() async {
    _localIP = await _scanner.getLocalIP();
    if (_localIP == null) {
      throw Exception('Could not determine local IP address');
    }

    // Find an available port
    _localPort = await _findAvailablePort();
    print('🌐 Local network: $_localIP:$_localPort');
  }

  /// Find an available port for the mesh service
  Future<int> _findAvailablePort() async {
    const maxAttempts = 10;
    final random = Random();

    for (int i = 0; i < maxAttempts; i++) {
      final port = _basePort + random.nextInt(1000);
      try {
        final serverSocket = await ServerSocket.bind(_localIP!, port);
        await serverSocket.close();
        return port;
      } catch (e) {
        // Port is in use, try another
        continue;
      }
    }

    // Fallback to random port
    return _basePort + random.nextInt(10000);
  }

  /// Start advertising this device via mDNS
  Future<void> _startAdvertising() async {
    try {
      // TODO: Implement mDNS advertising when dependencies are available
      /*
      final service = Service(
        name: '$_serviceName-$_deviceId',
        type: _serviceType,
        port: _localPort,
        txt: {
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'version': '1.0.0',
          'platform': 'Flutter',
        },
      );

      _serviceRegistration = await register(service);
      */
      print('📢 mDNS advertising disabled (dependencies not available)');
    } catch (e) {
      print('❌ Failed to start advertising: $e');
      // Continue without mDNS advertising
    }
  }

  /// Start discovering other devices via mDNS
  Future<void> _startDiscovering() async {
    try {
      // TODO: Implement mDNS discovery when dependencies are available
      /*
      _serviceDiscovery = await startDiscovery(_serviceType);

      _serviceDiscovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          _handleServiceFound(service);
        } else if (status == ServiceStatus.lost) {
          _handleServiceLost(service);
        }
      });
      */

      print('🔍 mDNS discovery disabled (dependencies not available)');
      print('🔍 Using fallback network scanning instead');
    } catch (e) {
      print('❌ Failed to start discovery: $e');
      // Continue without mDNS discovery
    }
  }

  /// Handle mDNS service found
  void _handleServiceFound(dynamic service) {
    try {
      // TODO: Implement when mDNS is available
      /*
      final deviceId = service.txt?['deviceId'];
      final deviceName = service.txt?['deviceName'] ?? 'Unknown Device';

      // Don't discover ourselves
      if (deviceId == _deviceId) return;

      if (deviceId != null && service.host != null) {
        final peer = MeshPeer(
          deviceId: deviceId,
          deviceName: deviceName,
          ipAddress: service.host!,
          port: service.port ?? _basePort,
          lastSeen: DateTime.now(),
          capabilities: PeerCapabilities.defaults(),
          status: PeerStatus.discovered,
        );

        onPeerDiscovered(peer);
      }
      */
    } catch (e) {
      print('❌ Error handling service found: $e');
    }
  }

  /// Handle mDNS service lost
  void _handleServiceLost(dynamic service) {
    try {
      // TODO: Implement when mDNS is available
      /*
      final deviceId = service.txt?['deviceId'];
      if (deviceId != null) {
        onPeerLost(deviceId);
      }
      */
    } catch (e) {
      print('❌ Error handling service lost: $e');
    }
  }

  /// Start periodic discovery
  void _startPeriodicDiscovery() {
    _discoveryTimer = Timer.periodic(_discoveryInterval, (_) {
      _performPeriodicDiscovery();
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _performHeartbeat();
    });
  }

  /// Perform periodic discovery
  Future<void> _performPeriodicDiscovery() async {
    try {
      // Remove stale peers
      final stalePeers = <String>[];
      for (final entry in _discoveredPeers.entries) {
        if (!entry.value.isAlive) {
          stalePeers.add(entry.key);
        }
      }

      for (final deviceId in stalePeers) {
        onPeerLost(deviceId);
      }

      // Optionally perform additional network scan
      if (_discoveredPeers.isEmpty) {
        await scanForPeers();
      }
    } catch (e) {
      print('❌ Error in periodic discovery: $e');
    }
  }

  /// Perform heartbeat
  Future<void> _performHeartbeat() async {
    try {
      // Update our own advertisement if needed
      await broadcastPresence();
    } catch (e) {
      print('❌ Error in heartbeat: $e');
    }
  }

  /// Probe a potential peer to get device information
  Future<MeshPeer?> _probePeer(String ip, int port) async {
    try {
      // This is a simplified probe - in a real implementation,
      // you would send a handshake message to get device info

      // For now, return a basic peer
      return MeshPeer(
        deviceId: 'peer-$ip-$port',
        deviceName: 'Device at $ip',
        ipAddress: ip,
        port: port,
        lastSeen: DateTime.now(),
        capabilities: PeerCapabilities.defaults(),
        status: PeerStatus.discovered,
      );
    } catch (e) {
      return null;
    }
  }

  /// Validate a discovered peer
  bool _validatePeer(MeshPeer peer) {
    // Basic validation
    if (peer.deviceId == _deviceId) return false;
    if (peer.ipAddress == _localIP && peer.port == _localPort) return false;
    if (peer.deviceId.isEmpty || peer.ipAddress.isEmpty) return false;

    return true;
  }

  /// Dispose resources
  void dispose() {
    _peersController.close();
    _peerDiscoveredController.close();
    _peerLostController.close();
  }
}

/// Network scanner utility for discovering devices on local network
class NetworkScanner {
  /// Scan local network for active hosts
  Future<List<String>> scanLocalNetwork() async {
    try {
      final localIP = await getLocalIP();
      if (localIP == null) return [];

      final networkPrefix = await getNetworkPrefix();
      final activeHosts = <String>[];

      // Scan common IP range (simplified)
      for (int i = 1; i <= 254; i++) {
        final ip = '$networkPrefix.$i';
        if (ip != localIP && await pingHost(ip)) {
          activeHosts.add(ip);
        }
      }

      return activeHosts;
    } catch (e) {
      print('❌ Error scanning network: $e');
      return [];
    }
  }

  /// Ping a host to check if it's alive
  Future<bool> pingHost(String ip) async {
    try {
      final result = await InternetAddress.lookup(ip);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Probe a specific port on a host
  Future<bool> probePort(String ip, int port) async {
    try {
      final socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get local IP address
  Future<String?> getLocalIP() async {
    try {
      // TODO: Use NetworkInfo when dependency is available
      // final info = NetworkInfo();
      // return await info.getWifiIP();

      // Fallback: get local IP using socket connection
      final socket = await Socket.connect('8.8.8.8', 80);
      final localIP = socket.address.address;
      socket.destroy();
      return localIP;
    } catch (e) {
      return '127.0.0.1'; // Fallback to localhost
    }
  }

  /// Get network prefix (e.g., "192.168.1" from "192.168.1.100")
  Future<String> getNetworkPrefix() async {
    final localIP = await getLocalIP();
    if (localIP == null) return '192.168.1';

    final parts = localIP.split('.');
    if (parts.length >= 3) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }

    return '192.168.1';
  }
}
