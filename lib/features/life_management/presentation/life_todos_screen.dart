import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_todo_list_detail_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_todo_list_editor_screen.dart';

class LifeTodosScreen extends ConsumerWidget {
  const LifeTodosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(lifeTodoListsProvider);
    final itemsAsync = ref.watch(lifeTodoItemsAllProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('待办')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<TodoList>(
            context,
            MaterialPageRoute(builder: (_) => const LifeTodoListEditorScreen()),
          );
          if (created == null || !context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LifeTodoListDetailScreen(list: created),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新建主题'),
      ),
      body: listsAsync.when(
        data: (lists) => itemsAsync.when(
          data: (items) => _TodoListsView(lists: lists, items: items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: '加载待办失败：$error',
            onRetry: () => ref.invalidate(lifeTodoItemsAllProvider),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '加载待办主题失败：$error',
          onRetry: () => ref.invalidate(lifeTodoListsProvider),
        ),
      ),
    );
  }
}

class _TodoListsView extends StatelessWidget {
  const _TodoListsView({required this.lists, required this.items});

  final List<TodoList> lists;
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return const _EmptyLifeState(
        icon: Icons.checklist_outlined,
        title: '还没有待办主题',
        subtitle: '点击右下角新建主题，例如“周末要做的10件事”。',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = lists[index];
        final listItems = items
            .where((item) => item.listId == list.id)
            .toList();
        return _TodoListTile(list: list, items: listItems);
      },
    );
  }
}

class _TodoListTile extends ConsumerWidget {
  const _TodoListTile({required this.list, required this.items});

  final TodoList list;
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = items
        .where((item) => item.status == TodoItemStatus.open)
        .length;
    final completed = items
        .where((item) => item.status == TodoItemStatus.completed)
        .length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.checklist_outlined),
        title: Text(list.title),
        subtitle: Text('未完成 $open · 已完成 $completed · 总计 ${items.length}'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeTodoListDetailScreen(list: list),
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LifeTodoListEditorScreen(list: list),
                ),
              );
              return;
            }
            final repository = await ref.read(
              lifeManagementRepositoryProvider.future,
            );
            await repository.archiveTodoList(list.id);
            ref.invalidate(lifeTodoListsProvider);
            ref.invalidate(lifeTodoItemsAllProvider);
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${list.title} 已归档')));
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'archive', child: Text('归档')),
          ],
        ),
      ),
    );
  }
}

class _EmptyLifeState extends StatelessWidget {
  const _EmptyLifeState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
