import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/todo_providers.dart';
import '../../core/services/sync_service.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final syncNotifierState = ref.watch(syncNotifierProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(syncStatusAsync),
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(syncStatusAsync, syncNotifierState),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimaryText(syncStatusAsync, syncNotifierState),
                _buildSecondaryText(syncStatusAsync),
              ],
            ),
          ),
          _buildActionButton(context, ref, syncStatusAsync, syncNotifierState),
        ],
      ),
    );
  }

  Color _getStatusColor(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected) return Colors.red.shade100;
        if (status.isSyncing) return Colors.blue.shade100;
        if (status.unresolvedConflicts > 0) return Colors.orange.shade100;
        if (status.pendingUploads > 0) return Colors.yellow.shade100;
        return Colors.green.shade100;
      },
      loading: () => Colors.grey.shade100,
      error: (_, __) => Colors.red.shade100,
    );
  }

  Widget _buildStatusIcon(
    AsyncValue<SyncStatus> syncStatusAsync,
    AsyncValue<SyncResult?> syncNotifierState,
  ) {
    if (syncNotifierState.isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected)
          return const Icon(Icons.cloud_off, color: Colors.red, size: 20);
        if (status.isSyncing)
          return const Icon(Icons.sync, color: Colors.blue, size: 20);
        if (status.unresolvedConflicts > 0)
          return const Icon(Icons.warning, color: Colors.orange, size: 20);
        if (status.pendingUploads > 0)
          return const Icon(Icons.cloud_upload, color: Colors.orange, size: 20);
        return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
      },
      loading: () => const Icon(Icons.refresh, color: Colors.grey, size: 20),
      error: (_, __) => const Icon(Icons.error, color: Colors.red, size: 20),
    );
  }

  Widget _buildPrimaryText(
    AsyncValue<SyncStatus> syncStatusAsync,
    AsyncValue<SyncResult?> syncNotifierState,
  ) {
    if (syncNotifierState.isLoading) {
      return const Text('Syncing...',
          style: TextStyle(fontWeight: FontWeight.bold));
    }

    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected)
          return const Text('Offline',
              style: TextStyle(fontWeight: FontWeight.bold));
        if (status.isSyncing)
          return const Text('Syncing...',
              style: TextStyle(fontWeight: FontWeight.bold));
        if (status.unresolvedConflicts > 0) {
          return Text(
            '${status.unresolvedConflicts} conflict(s) need resolution',
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        if (status.pendingUploads > 0) {
          return Text(
            '${status.pendingUploads} item(s) pending sync',
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        return const Text('All synced',
            style: TextStyle(fontWeight: FontWeight.bold));
      },
      loading: () => const Text('Checking status...',
          style: TextStyle(fontWeight: FontWeight.bold)),
      error: (_, __) => const Text('Sync error',
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSecondaryText(AsyncValue<SyncStatus> syncStatusAsync) {
    return syncStatusAsync.when(
      data: (status) {
        final lastSyncText = _formatLastSync(status.lastSyncAttempt);
        if (!status.isConnected) {
          return Text('Working offline • $lastSyncText',
              style: const TextStyle(fontSize: 12));
        }
        return Text('Connected • $lastSyncText',
            style: const TextStyle(fontSize: 12));
      },
      loading: () => const Text('Loading...', style: TextStyle(fontSize: 12)),
      error: (_, __) =>
          const Text('Error getting status', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SyncStatus> syncStatusAsync,
    AsyncValue<SyncResult?> syncNotifierState,
  ) {
    if (syncNotifierState.isLoading) {
      return const SizedBox.shrink();
    }

    return syncStatusAsync.when(
      data: (status) {
        if (!status.isConnected) {
          return IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.refresh(syncStatusProvider),
            tooltip: 'Check connection',
          );
        }

        if (status.unresolvedConflicts > 0) {
          return TextButton(
            onPressed: () =>
                ref.read(showConflictsProvider.notifier).state = true,
            child: const Text('Resolve'),
          );
        }

        if (status.pendingUploads > 0 || !status.isSyncing) {
          return IconButton(
            icon: const Icon(Icons.sync, size: 20),
            onPressed: () => ref.read(syncNotifierProvider.notifier).forcSync(),
            tooltip: 'Force sync',
          );
        }

        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        onPressed: () => ref.refresh(syncStatusProvider),
        tooltip: 'Retry',
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
