import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/todo_providers.dart';
import '../../domain/entities/conflict.dart';

class ConflictsView extends ConsumerWidget {
  const ConflictsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Conflicts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.read(showConflictsProvider.notifier).state = false,
        ),
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

          return ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return ConflictCard(conflict: conflict);
            },
          );
        },
      ),
    );
  }
}

class ConflictCard extends ConsumerWidget {
  final Conflict conflict;

  const ConflictCard({
    super.key,
    required this.conflict,
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
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conflict: ${conflict.getDescription()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Multiple devices edited this todo while offline. Choose which version to keep:',
              style: TextStyle(color: Colors.grey.shade600),
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
                          'The system can automatically resolve this conflict.'),
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissConflict(ref),
                  child: const Text('Dismiss'),
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
