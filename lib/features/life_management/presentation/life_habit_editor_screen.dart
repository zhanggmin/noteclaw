import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';

class LifeHabitEditorScreen extends ConsumerStatefulWidget {
  const LifeHabitEditorScreen({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<LifeHabitEditorScreen> createState() =>
      _LifeHabitEditorScreenState();
}

class _LifeHabitEditorScreenState extends ConsumerState<LifeHabitEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _targetValueController;
  late final TextEditingController _targetUnitController;
  HabitRecurrenceType _recurrenceType = HabitRecurrenceType.daily;
  Set<int> _selectedWeekdays = {DateTime.monday};
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _titleController = TextEditingController(text: habit?.title ?? '');
    _noteController = TextEditingController(text: habit?.note ?? '');
    _targetValueController = TextEditingController(
      text: habit?.target == null
          ? ''
          : _formatNumber(habit!.target!.targetValue),
    );
    _targetUnitController = TextEditingController(
      text: habit?.target?.unit ?? '',
    );
    _recurrenceType = habit?.recurrence.type ?? HabitRecurrenceType.daily;
    _selectedWeekdays = habit?.recurrence.weekdays.toSet() ?? {DateTime.monday};
    _reminderEnabled = habit?.reminder?.enabled ?? false;
    final reminderHour = habit?.reminder?.hour;
    final reminderMinute = habit?.reminder?.minute;
    if (reminderHour != null && reminderMinute != null) {
      _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _targetValueController.dispose();
    _targetUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.habit == null ? '新建习惯' : '编辑习惯')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            DropdownButtonFormField<HabitRecurrenceType>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(
                labelText: '重复规则',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: HabitRecurrenceType.daily,
                  child: Text('每天'),
                ),
                DropdownMenuItem(
                  value: HabitRecurrenceType.weekly,
                  child: Text('每周'),
                ),
                DropdownMenuItem(
                  value: HabitRecurrenceType.selectedWeekdays,
                  child: Text('指定星期'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _recurrenceType = value);
              },
            ),
            if (_recurrenceType == HabitRecurrenceType.selectedWeekdays) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _weekdayLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _selectedWeekdays.contains(entry.key),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeekdays.add(entry.key);
                          } else if (_selectedWeekdays.length > 1) {
                            _selectedWeekdays.remove(entry.key);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetValueController,
                    decoration: const InputDecoration(
                      labelText: '目标值',
                      hintText: '例如 1、30、5',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      if (double.tryParse(text) == null) return '请输入数字';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _targetUnitController,
                    decoration: const InputDecoration(
                      labelText: '单位',
                      hintText: '次、分钟、km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒'),
              subtitle: Text(
                _reminderEnabled
                    ? '${_formatTimeOfDay(_reminderTime)} 提醒'
                    : '不提醒',
              ),
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
              secondary: const Icon(Icons.notifications_outlined),
            ),
            if (_reminderEnabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('提醒时间'),
                subtitle: Text(_formatTimeOfDay(_reminderTime)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickReminderTime,
              ),
            ],
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
              label: Text(_saving ? '保存中...' : '保存'),
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
      final service = await ref.read(lifeManagementServiceProvider.future);
      final targetValue = double.tryParse(_targetValueController.text.trim());
      final unit = _targetUnitController.text.trim();
      final existing = widget.habit;
      final habit = Habit(
        id: existing?.id,
        title: _titleController.text.trim(),
        note: _emptyToNull(_noteController.text),
        tags: existing?.tags ?? const [],
        status: existing?.status ?? HabitStatus.active,
        recurrence: HabitRecurrence(
          type: _recurrenceType,
          weekdays: _recurrenceType == HabitRecurrenceType.selectedWeekdays
              ? (_selectedWeekdays.toList()..sort())
              : const [],
        ),
        target: targetValue == null
            ? null
            : HabitTarget(
                targetValue: targetValue,
                unit: unit.isEmpty ? '次' : unit,
              ),
        reminder: _reminderEnabled
            ? ReminderRule(
                id: existing?.reminder?.id,
                kind: _recurrenceType == HabitRecurrenceType.daily
                    ? ReminderKind.daily
                    : ReminderKind.weekly,
                hour: _reminderTime.hour,
                minute: _reminderTime.minute,
              )
            : null,
        createdAt: existing?.createdAt,
        archivedAt: existing?.archivedAt,
      );
      await service.saveHabit(habit);
      ref.invalidate(lifeHabitsProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time == null || !mounted) return;
    setState(() => _reminderTime = time);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

const _weekdayLabels = {
  DateTime.monday: '周一',
  DateTime.tuesday: '周二',
  DateTime.wednesday: '周三',
  DateTime.thursday: '周四',
  DateTime.friday: '周五',
  DateTime.saturday: '周六',
  DateTime.sunday: '周日',
};
