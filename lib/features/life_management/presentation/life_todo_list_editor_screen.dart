import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';

class LifeTodoListEditorScreen extends ConsumerStatefulWidget {
  const LifeTodoListEditorScreen({super.key, this.list});

  final TodoList? list;

  @override
  ConsumerState<LifeTodoListEditorScreen> createState() =>
      _LifeTodoListEditorScreenState();
}

class _LifeTodoListEditorScreenState
    extends ConsumerState<LifeTodoListEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagsController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final list = widget.list;
    _titleController = TextEditingController(text: list?.title ?? '');
    _noteController = TextEditingController(text: list?.note ?? '');
    _tagsController = TextEditingController(text: list?.tags.join('，') ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.list == null ? '新建待办主题' : '编辑待办主题')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '主题',
                hintText: '例如：周末要做的10件事',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入主题';
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
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '用逗号分隔，例如：周末，家庭',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中...' : '保存主题'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(
        lifeManagementRepositoryProvider.future,
      );
      final existing = widget.list;
      final stored = await repository.saveTodoList(
        TodoList(
          id: existing?.id,
          title: _titleController.text.trim(),
          note: _emptyToNull(_noteController.text),
          tags: _parseTags(_tagsController.text),
          status: existing?.status ?? TodoListStatus.active,
          createdAt: existing?.createdAt,
          archivedAt: existing?.archivedAt,
        ),
      );
      ref.invalidate(lifeTodoListsProvider);
      if (mounted) Navigator.pop(context, stored);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseTags(String value) {
    return value
        .split(RegExp(r'[,，]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
