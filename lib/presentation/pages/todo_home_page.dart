import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_list.dart';
import '../widgets/add_todo_dialog.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/conflicts_view.dart';

class TodoHomePage extends ConsumerWidget {
  const TodoHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showConflicts = ref.watch(showConflictsProvider);
    final conflictsAsync = ref.watch(conflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Todo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Conflicts indicator
          conflictsAsync.when(
            data: (conflicts) => conflicts.isNotEmpty
                ? IconButton(
                    icon: Badge(
                      label: Text('${conflicts.length}'),
                      child: const Icon(Icons.warning),
                    ),
                    onPressed: () => ref
                        .read(showConflictsProvider.notifier)
                        .state = !showConflicts,
                    tooltip: 'View conflicts',
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Sync button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncNotifierProvider.notifier).forcSync(),
            tooltip: 'Force sync',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync status bar
          const SyncStatusBar(),

          // Main content
          Expanded(
            child: showConflicts ? const ConflictsView() : const TodoList(),
          ),
        ],
      ),
      floatingActionButton: showConflicts
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddTodoDialog(context),
              tooltip: 'Add todo',
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );
  }
}
