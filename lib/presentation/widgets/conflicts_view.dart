import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/todo_providers.dart';
import '../../domain/entities/conflict.dart';

class ConflictsView extends ConsumerStatefulWidget {
  const ConflictsView({super.key});

  @override
  ConsumerState<ConflictsView> createState() => _ConflictsViewState();
}

class _ConflictsViewState extends ConsumerState<ConflictsView> {
  bool _compactView = true;

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflicts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.read(showConflictsProvider.notifier).state = false,
        ),
        actions: [
          // View toggle
          IconButton(
            icon: Icon(_compactView ? Icons.view_list : Icons.view_module),
            onPressed: () => setState(() => _compactView = !_compactView),
            tooltip: _compactView ? 'Detailed view' : 'Compact view',
          ),
          // Auto-resolve all button
          conflictsAsync.when(
            data: (conflicts) => conflicts.isNotEmpty
                ? PopupMenuButton(
                    icon: const Icon(Icons.auto_fix_high),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Auto-resolve all'),
                        onTap: () => _autoResolveAll(conflicts),
                      ),
                      PopupMenuItem(
                        child: const Text('Use latest versions'),
                        onTap: () => _useLatestVersions(conflicts),
                      ),
                      PopupMenuItem(
                        child: const Text('Dismiss all'),
                        onTap: () => _dismissAll(conflicts),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading conflicts: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(conflictsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No conflicts to resolve',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All todos are in sync!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Conflicts summary header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${conflicts.length} Conflict${conflicts.length > 1 ? 's' : ''} Found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Multiple devices edited the same todos while offline. '
                      'Choose which versions to keep or let the system auto-resolve.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          '${_getAutoResolvableCount(conflicts)} auto-resolvable',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.edit, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${conflicts.length - _getAutoResolvableCount(conflicts)} need manual review',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Conflicts list
              Expanded(
                child: _compactView
                    ? _buildCompactList(conflicts)
                    : _buildDetailedList(conflicts),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactList(List<Conflict> conflicts) {
    return ListView.builder(
      itemCount: conflicts.length,
      itemBuilder: (context, index) {
        final conflict = conflicts[index];
        return CompactConflictCard(
          conflict: conflict,
          index: index + 1,
          onExpand: () => setState(() => _compactView = false),
        );
      },
    );
  }

  Widget _buildDetailedList(List<Conflict> conflicts) {
    return ListView.builder(
      itemCount: conflicts.length,
      itemBuilder: (context, index) {
        final conflict = conflicts[index];
        return DetailedConflictCard(conflict: conflict, index: index + 1);
      },
    );
  }

  int _getAutoResolvableCount(List<Conflict> conflicts) {
    return conflicts.where((c) => c.getAutoResolutionWinner() != null).length;
  }

  void _autoResolveAll(List<Conflict> conflicts) {
    for (final conflict in conflicts) {
      final winner = conflict.getAutoResolutionWinner();
      if (winner != null) {
        ref.read(conflictNotifierProvider.notifier).resolveConflict(
              conflictId: conflict.id,
              selectedVersionId: winner.id,
            );
      }
    }
  }

  void _useLatestVersions(List<Conflict> conflicts) {
    for (final conflict in conflicts) {
      final latestVersion = conflict.versions
          .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
      ref.read(conflictNotifierProvider.notifier).resolveConflict(
            conflictId: conflict.id,
            selectedVersionId: latestVersion.id,
          );
    }
  }

  void _dismissAll(List<Conflict> conflicts) {
    for (final conflict in conflicts) {
      ref.read(conflictNotifierProvider.notifier).dismissConflict(conflict.id);
    }
  }
}

class CompactConflictCard extends ConsumerWidget {
  final Conflict conflict;
  final int index;
  final VoidCallback onExpand;

  const CompactConflictCard({
    super.key,
    required this.conflict,
    required this.index,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoWinner = conflict.getAutoResolutionWinner();
    final latestVersion = conflict.versions
        .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: autoWinner != null ? Colors.blue : Colors.orange,
          child: Text('$index', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(
          conflict.getDescription(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${conflict.versions.length} versions from different devices'),
            const SizedBox(height: 4),
            if (autoWinner != null)
              const Row(
                children: [
                  Icon(Icons.auto_fix_high, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Auto-resolvable', style: TextStyle(color: Colors.blue)),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Manual review needed',
                      style: TextStyle(color: Colors.orange)),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (autoWinner != null)
              ElevatedButton.icon(
                onPressed: () => _autoResolve(ref),
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Auto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _useLatestVersion(ref, latestVersion),
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('Latest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onExpand,
              icon: const Icon(Icons.expand_more),
              tooltip: 'View details',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...conflict.versions.take(3).map((version) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.device_hub,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${version.name} (\$${version.price.toStringAsFixed(2)}) - '
                              '${_getDeviceShortId(version.deviceId)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                if (conflict.versions.length > 3)
                  Text(
                    '... and ${conflict.versions.length - 3} more versions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: onExpand,
                      icon: const Icon(Icons.visibility),
                      label: const Text('View All'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showQuickResolveDialog(context, ref),
                      icon: const Icon(Icons.merge_type),
                      label: const Text('Manual Merge'),
                    ),
                    TextButton.icon(
                      onPressed: () => _dismissConflict(ref),
                      icon: const Icon(Icons.close),
                      label: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _autoResolve(WidgetRef ref) {
    final winner = conflict.getAutoResolutionWinner();
    if (winner != null) {
      ref.read(conflictNotifierProvider.notifier).resolveConflict(
            conflictId: conflict.id,
            selectedVersionId: winner.id,
          );
    }
  }

  void _useLatestVersion(WidgetRef ref, ConflictVersion latestVersion) {
    ref.read(conflictNotifierProvider.notifier).resolveConflict(
          conflictId: conflict.id,
          selectedVersionId: latestVersion.id,
        );
  }

  void _dismissConflict(WidgetRef ref) {
    ref.read(conflictNotifierProvider.notifier).dismissConflict(conflict.id);
  }

  void _showQuickResolveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => QuickResolveDialog(conflict: conflict),
    );
  }

  String _getDeviceShortId(String deviceId) {
    return deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
  }
}

class DetailedConflictCard extends ConsumerWidget {
  final Conflict conflict;
  final int index;

  const DetailedConflictCard({
    super.key,
    required this.conflict,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conflict header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text('$index',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conflict #$index: ${conflict.getDescription()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Multiple devices edited this todo while offline. Choose which version to keep:',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Version options
            ...conflict.versions.asMap().entries.map((entry) {
              final index = entry.key;
              final version = entry.value;
              return ConflictVersionOption(
                version: version,
                index: index,
                conflict: conflict,
              );
            }),

            const SizedBox(height: 16),

            // Auto-resolution option if available
            if (conflict.getAutoResolutionWinner() != null)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_fix_high, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Auto-resolution available',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'The system can automatically resolve this conflict using smart field-level merging.'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _autoResolve(ref),
                        child: const Text('Auto-resolve'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Manual merge option
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.merge_type, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Manual merge',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Create a custom version by combining parts from different versions.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showManualMergeDialog(context, ref),
                      child: const Text('Manual merge'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _dismissConflict(ref),
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _useLatestVersion(ref),
                      icon: const Icon(Icons.schedule),
                      label: const Text('Use Latest'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (conflict.getAutoResolutionWinner() != null)
                      ElevatedButton.icon(
                        onPressed: () => _autoResolve(ref),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Auto-resolve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _autoResolve(WidgetRef ref) {
    final winner = conflict.getAutoResolutionWinner();
    if (winner != null) {
      ref.read(conflictNotifierProvider.notifier).resolveConflict(
            conflictId: conflict.id,
            selectedVersionId: winner.id,
          );
    }
  }

  void _useLatestVersion(WidgetRef ref) {
    final latestVersion = conflict.versions
        .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
    ref.read(conflictNotifierProvider.notifier).resolveConflict(
          conflictId: conflict.id,
          selectedVersionId: latestVersion.id,
        );
  }

  void _dismissConflict(WidgetRef ref) {
    ref.read(conflictNotifierProvider.notifier).dismissConflict(conflict.id);
  }

  void _showManualMergeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ManualMergeDialog(conflict: conflict),
    );
  }
}

class ConflictVersionOption extends ConsumerWidget {
  final ConflictVersion version;
  final int index;
  final Conflict conflict;

  const ConflictVersionOption({
    super.key,
    required this.version,
    required this.index,
    required this.conflict,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          'Version ${index + 1}: ${version.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: \$${version.price.toStringAsFixed(2)}'),
            Text('Status: ${version.isCompleted ? 'Completed' : 'Pending'}'),
            if (version.isDeleted)
              const Text(
                'DELETED',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 4),
            Text(
              'Device: ${_getDeviceShortId(version.deviceId)} • ${_formatDate(version.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _selectVersion(ref),
          child: const Text('Choose'),
        ),
      ),
    );
  }

  void _selectVersion(WidgetRef ref) {
    ref.read(conflictNotifierProvider.notifier).resolveConflict(
          conflictId: conflict.id,
          selectedVersionId: version.id,
        );
  }

  String _getDeviceShortId(String deviceId) {
    return deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class ManualMergeDialog extends ConsumerStatefulWidget {
  final Conflict conflict;

  const ManualMergeDialog({
    super.key,
    required this.conflict,
  });

  @override
  ConsumerState<ManualMergeDialog> createState() => _ManualMergeDialogState();
}

class _ManualMergeDialogState extends ConsumerState<ManualMergeDialog> {
  late String selectedName;
  late double selectedPrice;
  late bool selectedCompletion;

  @override
  void initState() {
    super.initState();
    // Initialize with first version's values
    final firstVersion = widget.conflict.versions.first;
    selectedName = firstVersion.name;
    selectedPrice = firstVersion.price;
    selectedCompletion = firstVersion.isCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Merge'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select the values you want to keep:'),
            const SizedBox(height: 16),

            // Name selection
            _buildFieldSelector(
              label: 'Name',
              values:
                  widget.conflict.versions.map((v) => v.name).toSet().toList(),
              selectedValue: selectedName,
              onChanged: (value) => setState(() => selectedName = value),
            ),

            const SizedBox(height: 16),

            // Price selection
            _buildFieldSelector(
              label: 'Price',
              values: widget.conflict.versions
                  .map((v) => '\$${v.price.toStringAsFixed(2)}')
                  .toSet()
                  .toList(),
              selectedValue: '\$${selectedPrice.toStringAsFixed(2)}',
              onChanged: (value) {
                final price = double.parse(value.substring(1));
                setState(() => selectedPrice = price);
              },
            ),

            const SizedBox(height: 16),

            // Completion selection
            _buildFieldSelector(
              label: 'Status',
              values: const ['Pending', 'Completed'],
              selectedValue: selectedCompletion ? 'Completed' : 'Pending',
              onChanged: (value) =>
                  setState(() => selectedCompletion = value == 'Completed'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveMerge,
          child: const Text('Save Merge'),
        ),
      ],
    );
  }

  Widget _buildFieldSelector({
    required String label,
    required List<String> values,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...values.map((value) => RadioListTile<String>(
              title: Text(value),
              value: value,
              groupValue: selectedValue,
              onChanged: (v) => onChanged(v!),
              dense: true,
            )),
      ],
    );
  }

  void _saveMerge() {
    ref.read(conflictNotifierProvider.notifier).resolveConflictWithMerge(
          conflictId: widget.conflict.id,
          selectedName: selectedName,
          selectedPrice: selectedPrice,
          selectedCompletion: selectedCompletion,
        );
    Navigator.of(context).pop();
  }
}

class QuickResolveDialog extends ConsumerStatefulWidget {
  final Conflict conflict;

  const QuickResolveDialog({
    super.key,
    required this.conflict,
  });

  @override
  ConsumerState<QuickResolveDialog> createState() => _QuickResolveDialogState();
}

class _QuickResolveDialogState extends ConsumerState<QuickResolveDialog> {
  String? _selectedAction;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Resolve Options'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.conflict.getAutoResolutionWinner() != null)
              RadioListTile<String>(
                title: const Text('Auto-resolve this conflict'),
                subtitle: const Text('Use smart field-level merging'),
                value: 'auto_resolve',
                groupValue: _selectedAction,
                onChanged: (value) => setState(() => _selectedAction = value),
              ),
            RadioListTile<String>(
              title: const Text('Use the latest version'),
              subtitle: const Text('Choose the most recently updated version'),
              value: 'use_latest',
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            RadioListTile<String>(
              title: const Text('Dismiss this conflict'),
              subtitle: const Text('Remove conflict without resolving'),
              value: 'dismiss',
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedAction != null ? _performQuickResolve : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _performQuickResolve() {
    if (_selectedAction == 'auto_resolve') {
      final winner = widget.conflict.getAutoResolutionWinner();
      if (winner != null) {
        ref.read(conflictNotifierProvider.notifier).resolveConflict(
              conflictId: widget.conflict.id,
              selectedVersionId: winner.id,
            );
      }
    } else if (_selectedAction == 'use_latest') {
      final latestVersion = widget.conflict.versions
          .reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
      ref.read(conflictNotifierProvider.notifier).resolveConflict(
            conflictId: widget.conflict.id,
            selectedVersionId: latestVersion.id,
          );
    } else if (_selectedAction == 'dismiss') {
      ref
          .read(conflictNotifierProvider.notifier)
          .dismissConflict(widget.conflict.id);
    }
    Navigator.of(context).pop();
  }
}
