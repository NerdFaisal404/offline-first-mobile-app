import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mesh_peer.dart';
import '../providers/app_providers.dart';

class DeviceDiscoveryView extends ConsumerStatefulWidget {
  const DeviceDiscoveryView({super.key});

  @override
  ConsumerState<DeviceDiscoveryView> createState() =>
      _DeviceDiscoveryViewState();
}

class _DeviceDiscoveryViewState extends ConsumerState<DeviceDiscoveryView> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshNetworkStatus() async {
    try {
      final meshDataSource = ref.read(meshDataSourceProvider);
      meshDataSource.getComprehensiveStatus();
      // Status will be automatically updated via providers
    } catch (e) {
      print('Error refreshing network status: $e');
    }
  }

  Future<void> _scanForPeers() async {
    setState(() => _isScanning = true);

    try {
      final meshDataSource = ref.read(meshDataSourceProvider);
      await meshDataSource.scanForPeers();
      await Future.delayed(
          const Duration(seconds: 2)); // Give time for discovery
      await _refreshNetworkStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToPeer(MeshPeer peer) async {
    try {
      final meshDataSource = ref.read(meshDataSourceProvider);
      final success = await meshDataSource.connectToPeer(peer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Connected to ${peer.deviceName}'
                : 'Failed to connect to ${peer.deviceName}'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }

      if (success) {
        await _refreshNetworkStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    }
  }

  void _disconnectFromPeer(String peerId) {
    try {
      final meshDataSource = ref.read(meshDataSourceProvider);
      meshDataSource.disconnectFromPeer(peerId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disconnected from peer'),
          backgroundColor: Colors.orange,
        ),
      );

      _refreshNetworkStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comprehensiveStatusAsync = ref.watch(meshComprehensiveStatusProvider);

    return comprehensiveStatusAsync.when(
      data: (networkStatus) {
        final deviceInfo = networkStatus['device'] as Map<String, dynamic>;
        final networkInfo = networkStatus['network'] as Map<String, dynamic>;
        final stats = networkStatus['statistics'] as Map<String, dynamic>;
        final isReady = networkStatus['isReady'] as bool;

        return RefreshIndicator(
          onRefresh: _refreshNetworkStatus,
          child: Column(
            children: [
              // Device Info Card
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isReady ? Icons.check_circle : Icons.error,
                            color: isReady ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Device Status: ${isReady ? 'Ready' : 'Not Ready'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Name: ${deviceInfo['deviceName']}'),
                      Text('ID: ${deviceInfo['deviceId']}'),
                      Text('Platform: ${deviceInfo['platform']}'),
                    ],
                  ),
                ),
              ),

              // Network Status Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mesh Network',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanForPeers,
                            icon: _isScanning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.search),
                            label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            networkInfo['isHealthy']
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: networkInfo['isHealthy']
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(networkInfo['isActive'] ? 'Active' : 'Inactive'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          _buildStatusChip(
                              'Discovered', networkInfo['discoveredPeers']),
                          _buildStatusChip(
                              'Available', networkInfo['availablePeers']),
                          _buildStatusChip(
                              'Connected', networkInfo['connectedPeers']),
                          _buildStatusChip(
                              'Syncing', networkInfo['activeSyncs']),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Sync Statistics Card
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Statistics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          _buildStatChip(
                              'Total', stats['totalSyncs'], Colors.blue),
                          _buildStatChip('Success', stats['successfulSyncs'],
                              Colors.green),
                          _buildStatChip(
                              'Failed', stats['failedSyncs'], Colors.red),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Success Rate: ${stats['successRate'].toStringAsFixed(1)}%'),
                      Text('Todos Synced: ${stats['totalTodosSynced']}'),
                      Text(
                          'Conflicts Resolved: ${stats['totalConflictsResolved']}'),
                    ],
                  ),
                ),
              ),

              // Discovered Peers List
              Expanded(
                child: _buildPeersList(),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            ElevatedButton(
              onPressed: _refreshNetworkStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count) {
    return Chip(
      label: Text(
        '$label: $count',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: count > 0 ? Colors.green.shade100 : Colors.grey.shade200,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Chip(
      label: Text(
        '$label: $count',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPeersList() {
    final discoveredPeersAsync = ref.watch(discoveredPeersProvider);

    return discoveredPeersAsync.when(
      data: (discoveredPeers) {
        try {
          final meshDataSource = ref.read(meshDataSourceProvider);
          final availablePeers = meshDataSource.getAvailablePeers();
          final connectedPeers = meshDataSource.getConnectedPeers();

          if (discoveredPeers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No devices discovered',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap "Scan" to discover nearby devices',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: discoveredPeers.length,
            itemBuilder: (context, index) {
              final peer = discoveredPeers[index];
              final isAvailable =
                  availablePeers.any((p) => p.deviceId == peer.deviceId);
              final isConnected = connectedPeers.contains(peer.deviceId);

              return Card(
                child: ListTile(
                  leading: Icon(
                    _getPeerIcon(peer),
                    color: isConnected
                        ? Colors.green
                        : isAvailable
                            ? Colors.orange
                            : Colors.grey,
                  ),
                  title: Text(peer.deviceName.isNotEmpty
                      ? peer.deviceName
                      : 'Unknown Device'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${peer.deviceId}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'IP: ${peer.ipAddress}:${peer.port}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Status: ${_getPeerStatus(isConnected, isAvailable)}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (peer.lastSeen != null)
                        Text(
                          'Last seen: ${_formatTime(peer.lastSeen!)}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                  trailing: _buildPeerActions(peer, isConnected, isAvailable),
                  isThreeLine: true,
                ),
              );
            },
          );
        } catch (e) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading peers: $e'),
                ElevatedButton(
                  onPressed: _refreshNetworkStatus,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading devices...'),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            ElevatedButton(
              onPressed: _refreshNetworkStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPeerIcon(MeshPeer peer) {
    // You could enhance this based on peer capabilities or device type
    return Icons.devices;
  }

  String _getPeerStatus(bool isConnected, bool isAvailable) {
    if (isConnected) return 'Connected';
    if (isAvailable) return 'Available';
    return 'Offline';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildPeerActions(MeshPeer peer, bool isConnected, bool isAvailable) {
    if (isConnected) {
      return IconButton(
        icon: const Icon(Icons.close, color: Colors.red),
        onPressed: () => _disconnectFromPeer(peer.deviceId),
        tooltip: 'Disconnect',
      );
    } else if (isAvailable) {
      return IconButton(
        icon: const Icon(Icons.link, color: Colors.green),
        onPressed: () => _connectToPeer(peer),
        tooltip: 'Connect',
      );
    } else {
      return const Icon(Icons.link_off, color: Colors.grey);
    }
  }
}
