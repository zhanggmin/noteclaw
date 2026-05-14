import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';

class LifeRecordTemplateEditorScreen extends ConsumerStatefulWidget {
  const LifeRecordTemplateEditorScreen({super.key, this.template});

  final RecordTemplate? template;

  @override
  ConsumerState<LifeRecordTemplateEditorScreen> createState() =>
      _LifeRecordTemplateEditorScreenState();
}

class _LifeRecordTemplateEditorScreenState
    extends ConsumerState<LifeRecordTemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _fieldsController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _fieldsController = TextEditingController(
      text: template?.fields.map((field) => field.label).join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fieldsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template == null ? '新建模板' : '编辑模板')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模板名称',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入模板名称';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '说明',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fieldsController,
              decoration: const InputDecoration(
                labelText: '字段',
                hintText: '每行一个字段，例如：金额\n店铺\n备注',
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: 10,
              validator: (value) {
                final fields = _parseFieldLabels(value ?? '');
                if (fields.isEmpty) return '至少输入一个字段';
                return null;
              },
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
              label: Text(_saving ? '保存中...' : '保存模板'),
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
      final existing = widget.template;
      final labels = _parseFieldLabels(_fieldsController.text);
      final template = RecordTemplate(
        id: existing?.id ?? _newTemplateId(),
        name: _nameController.text.trim(),
        description: _emptyToNull(_descriptionController.text),
        fields: [
          for (var i = 0; i < labels.length; i++)
            RecordTemplateField(
              key: existing != null && i < existing.fields.length
                  ? existing.fields[i].key
                  : _fieldKey(labels[i], i),
              label: labels[i],
            ),
        ],
        defaultTags: existing?.defaultTags ?? const [],
        defaultReminderDays: existing?.defaultReminderDays,
        createdAt: existing?.createdAt,
      );
      await repository.saveTemplate(template);
      ref.invalidate(lifeRecordTemplatesProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseFieldLabels(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList();
  }

  String _newTemplateId() {
    return 'custom_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _fieldKey(String label, int index) {
    final normalized = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '');
    if (normalized.isNotEmpty) return normalized;
    return 'field_${index + 1}';
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
