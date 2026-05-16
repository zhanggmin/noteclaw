import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_todo_list_editor_screen.dart';

class LifeTodoListDetailScreen extends ConsumerWidget {
  const LifeTodoListDetailScreen({super.key, required this.list});

  final TodoList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lifeTodoItemsProvider(list.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(list.title),
        actions: [
          IconButton(
            tooltip: '批量新增',
            onPressed: () => _showBulkItemSheet(context, listId: list.id),
            icon: const Icon(Icons.playlist_add_outlined),
          ),
          IconButton(
            tooltip: '编辑主题',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LifeTodoListEditorScreen(list: list),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemSheet(context, listId: list.id),
        icon: const Icon(Icons.add),
        label: const Text('新建待办'),
      ),
      body: itemsAsync.when(
        data: (items) => _TodoItemsView(list: list, items: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '加载待办失败：$error',
          onRetry: () => ref.invalidate(lifeTodoItemsProvider(list.id)),
        ),
      ),
    );
  }
}

class _TodoItemsView extends StatelessWidget {
  const _TodoItemsView({required this.list, required this.items});

  final TodoList list;
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context) {
    final open = items
        .where((item) => item.status == TodoItemStatus.open)
        .length;
    final completed = items
        .where((item) => item.status == TodoItemStatus.completed)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (list.note != null && list.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(list.note!),
                ],
                const SizedBox(height: 12),
                Text('未完成 $open · 已完成 $completed · 总计 ${items.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _EmptyLifeState(
            icon: Icons.checklist_outlined,
            title: '还没有待办',
            subtitle: '点击右下角新建待办，逐条添加要完成的事。',
          )
        else
          for (final item in items) ...[
            _TodoItemTile(item: item),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TodoItemTile extends ConsumerWidget {
  const _TodoItemTile({required this.item});

  final TodoItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = item.status == TodoItemStatus.completed;
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: completed,
          onChanged: (value) => _toggle(context, ref, value ?? false),
        ),
        title: Text(
          item.title,
          style: completed
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: _subtitle(),
        onTap: () => _showItemSheet(context, listId: item.listId, item: item),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) async {
            if (value == 'edit') {
              await _showItemSheet(context, listId: item.listId, item: item);
              return;
            }
            final repository = await ref.read(
              lifeManagementRepositoryProvider.future,
            );
            await repository.archiveTodoItem(item.id);
            if (!context.mounted) return;
            ref.invalidate(lifeTodoItemsProvider(item.listId));
            ref.invalidate(lifeTodoItemsAllProvider);
            ref.invalidate(lifeDueTodoItemsProvider);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${item.title} 已归档')));
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'archive', child: Text('归档')),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget? _subtitle() {
    final parts = <String>[];
    if (item.dueAt != null) parts.add('截止 ${_formatDate(item.dueAt!)}');
    if (item.note != null && item.note!.isNotEmpty) parts.add(item.note!);
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool completed,
  ) async {
    final repository = await ref.read(lifeManagementRepositoryProvider.future);
    await repository.completeTodoItem(item.id, completed: completed);
    if (!context.mounted) return;
    ref.invalidate(lifeTodoItemsProvider(item.listId));
    ref.invalidate(lifeTodoItemsAllProvider);
    ref.invalidate(lifeDueTodoItemsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(completed ? '${item.title} 已完成' : '${item.title} 已恢复'),
      ),
    );
  }
}

Future<void> _showItemSheet(
  BuildContext parentContext, {
  required String listId,
  TodoItem? item,
}) async {
  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TodoItemSheet(listId: listId, item: item),
  );
}

Future<void> _showBulkItemSheet(
  BuildContext parentContext, {
  required String listId,
}) async {
  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BulkTodoItemSheet(listId: listId),
  );
}

class _BulkTodoItemSheet extends ConsumerStatefulWidget {
  const _BulkTodoItemSheet({required this.listId});

  final String listId;

  @override
  ConsumerState<_BulkTodoItemSheet> createState() => _BulkTodoItemSheetState();
}

class _BulkTodoItemSheetState extends ConsumerState<_BulkTodoItemSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _parseBulkTodoTitles(_controller.text).length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('批量新增待办', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '每行一个待办。支持粘贴编号、短横线或 checkbox 清单。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '待办清单',
                hintText: '买菜\n整理书桌\n1. 洗衣服\n- 倒垃圾',
                border: OutlineInputBorder(),
              ),
              minLines: 8,
              maxLines: 14,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving || count == 0 ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check_outlined),
              label: Text(_saving ? '保存中...' : '新增 $count 条待办'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final titles = _parseBulkTodoTitles(_controller.text);
    if (titles.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(
        lifeManagementRepositoryProvider.future,
      );
      for (final title in titles) {
        await repository.saveTodoItem(
          TodoItem(listId: widget.listId, title: title),
        );
      }
      if (!mounted) return;
      ref.invalidate(lifeTodoItemsProvider(widget.listId));
      ref.invalidate(lifeTodoItemsAllProvider);
      ref.invalidate(lifeDueTodoItemsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已新增 ${titles.length} 条待办')));
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TodoItemSheet extends ConsumerStatefulWidget {
  const _TodoItemSheet({required this.listId, this.item});

  final String listId;
  final TodoItem? item;

  @override
  ConsumerState<_TodoItemSheet> createState() => _TodoItemSheetState();
}

class _TodoItemSheetState extends ConsumerState<_TodoItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  DateTime? _dueAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _dueAt = item?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item == null ? '新建待办' : '编辑待办',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '待办',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请输入待办';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('截止时间'),
                subtitle: Text(_dueAt == null ? '不设置' : _formatDate(_dueAt!)),
                trailing: Wrap(
                  children: [
                    if (_dueAt != null)
                      IconButton(
                        tooltip: '清除',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _dueAt = null),
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: '选择日期',
                      onPressed: _saving ? null : _pickDueDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中...' : '保存待办'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (!mounted || selected == null) return;
    setState(() => _dueAt = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(
        lifeManagementRepositoryProvider.future,
      );
      final existing = widget.item;
      await repository.saveTodoItem(
        TodoItem(
          id: existing?.id,
          listId: widget.listId,
          title: _titleController.text.trim(),
          note: _emptyToNull(_noteController.text),
          status: existing?.status ?? TodoItemStatus.open,
          dueAt: _dueAt,
          completedAt: existing?.completedAt,
          createdAt: existing?.createdAt,
        ),
      );
      if (!mounted) return;
      ref.invalidate(lifeTodoItemsProvider(widget.listId));
      ref.invalidate(lifeTodoItemsAllProvider);
      ref.invalidate(lifeDueTodoItemsProvider);
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _parseBulkTodoTitles(String value) {
  final seen = <String>{};
  final titles = <String>[];
  for (final line in value.split('\n')) {
    final title = line
        .trim()
        .replaceFirst(RegExp(r'^(([-*•])|(\d+[\.)])|(\[[ xX]\]))\s*'), '')
        .trim();
    if (title.isEmpty || seen.contains(title)) continue;
    seen.add(title);
    titles.add(title);
  }
  return titles;
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
