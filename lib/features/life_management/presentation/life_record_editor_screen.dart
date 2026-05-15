import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';

class LifeRecordEditorScreen extends ConsumerStatefulWidget {
  const LifeRecordEditorScreen({super.key, this.record, this.template});

  final LifeRecord? record;
  final RecordTemplate? template;

  @override
  ConsumerState<LifeRecordEditorScreen> createState() =>
      _LifeRecordEditorScreenState();
}

class _LifeRecordEditorScreenState
    extends ConsumerState<LifeRecordEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fieldControllers = <String, TextEditingController>{};
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _occurredAt;
  DateTime? _reminderAt;
  String? _templateId;
  bool _reminderEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _templateId = record?.templateId ?? widget.template?.id;
    _titleController = TextEditingController(text: record?.title ?? '');
    _noteController = TextEditingController(text: record?.note ?? '');
    _occurredAt = record?.occurredAt ?? DateTime.now();
    _reminderEnabled = record?.reminder?.enabled ?? false;
    _reminderAt = record?.reminder?.scheduledAt;
    if (record == null && widget.template?.defaultReminderDays != null) {
      _reminderEnabled = true;
      _reminderAt = _occurredAt.add(
        Duration(days: widget.template!.defaultReminderDays!),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(lifeRecordTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.record == null ? '新建记录' : '编辑记录')),
      body: templatesAsync.when(
        data: (templates) => _buildForm(context, templates),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载模板失败：$error')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<RecordTemplate> templates) {
    final selectedTemplate = _selectedTemplate(templates);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.template != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.article_outlined),
              title: const Text('模板'),
              subtitle: Text(widget.template!.name),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedTemplate?.id,
              decoration: const InputDecoration(
                labelText: '模板',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final template in templates)
                  DropdownMenuItem(
                    value: template.id,
                    child: Text(template.name),
                  ),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return '请选择模板';
                return null;
              },
              onChanged: (value) {
                if (value == null) return;
                final template = templates.firstWhere(
                  (item) => item.id == value,
                );
                setState(() {
                  _templateId = value;
                  if (_titleController.text.trim().isEmpty) {
                    _titleController.text = template.name;
                  }
                  _applyTemplateReminder(template);
                });
              },
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '请输入标题';
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
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('记录时间'),
            subtitle: Text(_formatDateTime(_occurredAt)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickOccurredAt,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('后续提醒'),
            subtitle: Text(
              _reminderEnabled && _reminderAt != null
                  ? _formatDateTime(_reminderAt!)
                  : '不提醒',
            ),
            value: _reminderEnabled,
            onChanged: (value) {
              setState(() {
                _reminderEnabled = value;
                _reminderAt ??= _defaultReminderAt(selectedTemplate);
              });
            },
            secondary: const Icon(Icons.notifications_outlined),
          ),
          if (_reminderEnabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('提醒时间'),
              subtitle: Text(
                _reminderAt == null ? '请选择提醒时间' : _formatDateTime(_reminderAt!),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _pickReminderAt(selectedTemplate),
            ),
          ],
          if (selectedTemplate != null) ...[
            const SizedBox(height: 16),
            Text('字段', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final field in selectedTemplate.fields) ...[
              TextFormField(
                controller: _controllerFor(field.key),
                decoration: InputDecoration(
                  labelText: field.unit == null
                      ? field.label
                      : '${field.label} (${field.unit})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: _keyboardType(field.type),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (field.required && text.isEmpty) {
                    return '请输入${field.label}';
                  }
                  if (text.isEmpty) return null;
                  if (_requiresNumber(field.type) &&
                      double.tryParse(text) == null) {
                    return '请输入数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(selectedTemplate),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }

  RecordTemplate? _selectedTemplate(List<RecordTemplate> templates) {
    if (widget.template != null) return widget.template;
    if (templates.isEmpty) return null;
    final id = _templateId ?? widget.record?.templateId ?? templates.first.id;
    _templateId ??= id;
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return templates.first;
  }

  TextEditingController _controllerFor(String key) {
    return _fieldControllers.putIfAbsent(key, () {
      final value = widget.record?.fields[key];
      return TextEditingController(text: value == null ? '' : '$value');
    });
  }

  TextInputType _keyboardType(RecordFieldType type) {
    return switch (type) {
      RecordFieldType.number ||
      RecordFieldType.money ||
      RecordFieldType.odometer ||
      RecordFieldType.quantity => const TextInputType.numberWithOptions(
        decimal: true,
      ),
      RecordFieldType.date => TextInputType.datetime,
      RecordFieldType.text => TextInputType.text,
    };
  }

  bool _requiresNumber(RecordFieldType type) {
    return switch (type) {
      RecordFieldType.number ||
      RecordFieldType.money ||
      RecordFieldType.odometer ||
      RecordFieldType.quantity => true,
      RecordFieldType.date || RecordFieldType.text => false,
    };
  }

  Future<void> _save(RecordTemplate? template) async {
    if (!_formKey.currentState!.validate()) return;
    if (template == null) return;
    setState(() => _saving = true);
    try {
      final service = await ref.read(lifeManagementServiceProvider.future);
      final existing = widget.record;
      final fields = <String, dynamic>{};
      for (final field in template.fields) {
        final text = _controllerFor(field.key).text.trim();
        if (text.isEmpty) continue;
        fields[field.key] = _requiresNumber(field.type)
            ? double.tryParse(text) ?? text
            : text;
      }
      final record = LifeRecord(
        id: existing?.id,
        templateId: template.id,
        title: _titleController.text.trim(),
        note: _emptyToNull(_noteController.text),
        tags: existing?.tags ?? template.defaultTags,
        fields: fields,
        status: existing?.status ?? LifeRecordStatus.active,
        occurredAt: _occurredAt,
        createdAt: existing?.createdAt,
        archivedAt: existing?.archivedAt,
        reminder: _reminderEnabled && _reminderAt != null
            ? ReminderRule(
                id: existing?.reminder?.id,
                kind: ReminderKind.once,
                scheduledAt: _reminderAt,
              )
            : null,
      );
      await service.saveRecord(record);
      ref.invalidate(lifeRecordsProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickOccurredAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickReminderAt(RecordTemplate? template) async {
    final initial = _reminderAt ?? _defaultReminderAt(template);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _reminderAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _applyTemplateReminder(RecordTemplate template) {
    if (widget.record != null) return;
    if (template.defaultReminderDays == null) return;
    _reminderEnabled = true;
    _reminderAt = _defaultReminderAt(template);
  }

  DateTime _defaultReminderAt(RecordTemplate? template) {
    final days = template?.defaultReminderDays ?? 30;
    return _occurredAt.add(Duration(days: days));
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$date $time';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
