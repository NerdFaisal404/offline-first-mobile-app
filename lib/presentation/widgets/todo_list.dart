import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/todo_providers.dart';
import '../../domain/entities/todo.dart';

class TodoList extends ConsumerWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);

    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading todos: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(todosProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (todos) {
        final activeTodos = todos.where((todo) => !todo.isDeleted).toList();

        if (activeTodos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checklist, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No todos yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap + to add your first todo',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activeTodos.length,
          itemBuilder: (context, index) {
            final todo = activeTodos[index];
            return TodoItem(todo: todo);
          },
        );
      },
    );
  }
}

class TodoItem extends ConsumerWidget {
  final Todo todo;

  const TodoItem({
    super.key,
    required this.todo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoNotifier = ref.read(todoNotifierProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => todoNotifier.toggleTodoCompletion(todo.id),
        ),
        title: Text(
          todo.name,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${todo.price.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                // Sync status indicator
                Icon(
                  todo.syncId != null ? Icons.cloud_done : Icons.cloud_upload,
                  size: 16,
                  color: todo.syncId != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  todo.syncId != null ? 'Synced' : 'Pending sync',
                  style: TextStyle(
                    fontSize: 12,
                    color: todo.syncId != null ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                // Device indicator
                Text(
                  'Device: ${_getDeviceShortId(todo.deviceId)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, ref, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    final todoNotifier = ref.read(todoNotifierProvider.notifier);

    switch (action) {
      case 'edit':
        _showEditDialog(context, ref);
        break;
      case 'delete':
        _showDeleteConfirmation(context, todoNotifier);
        break;
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: todo.name);
    final priceController = TextEditingController(text: todo.price.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Todo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text);

              if (name.isNotEmpty && price != null && price >= 0) {
                ref.read(todoNotifierProvider.notifier).updateTodo(
                      todoId: todo.id,
                      name: name,
                      price: price,
                    );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, TodoNotifier todoNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Are you sure you want to delete "${todo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              todoNotifier.deleteTodo(todo.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getDeviceShortId(String deviceId) {
    return deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
  }
}
