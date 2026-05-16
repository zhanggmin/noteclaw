import 'dart:convert';
import 'dart:io';

import 'package:flutterclaw/features/life_management/domain/life_management_models.dart';

class LifeRecordSearchQuery {
  final String? templateId;
  final String? text;
  final List<String> tags;
  final DateTime? from;
  final DateTime? to;
  final bool includeArchived;
  final int? limit;

  const LifeRecordSearchQuery({
    this.templateId,
    this.text,
    this.tags = const [],
    this.from,
    this.to,
    this.includeArchived = false,
    this.limit,
  });
}

class LifeManagementRepository {
  static const schemaVersion = 1;

  final Directory root;
  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

  LifeManagementRepository(this.root);

  File get _habitsFile => File('${root.path}/habits.json');
  File get _checkInsFile => File('${root.path}/habit_checkins.jsonl');
  File get _recordsFile => File('${root.path}/records.jsonl');
  File get _templatesFile => File('${root.path}/templates.json');
  File get _todoListsFile => File('${root.path}/todo_lists.json');
  File get _todoItemsFile => File('${root.path}/todo_items.jsonl');

  Future<void> initialize() async {
    await root.create(recursive: true);
    await Directory('${root.path}/attachments').create(recursive: true);
    await ensureDefaultTemplates();
  }

  Future<List<RecordTemplate>> ensureDefaultTemplates() async {
    final existing = await loadTemplates();
    final byId = {for (final template in existing) template.id: template};
    var changed = false;
    for (final template in defaultRecordTemplates()) {
      if (!byId.containsKey(template.id)) {
        byId[template.id] = template;
        changed = true;
      }
    }
    final templates = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (changed) await saveTemplates(templates);
    return templates;
  }

  Future<List<Habit>> loadHabits({bool includeArchived = false}) async {
    final items = await _readJsonList(_habitsFile);
    final habits = items.map(Habit.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (includeArchived) return habits;
    return habits
        .where((habit) => habit.status != HabitStatus.archived)
        .toList();
  }

  Future<Habit> saveHabit(Habit habit) async {
    final habits = await loadHabits(includeArchived: true);
    final index = habits.indexWhere((item) => item.id == habit.id);
    final stored = habit.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      habits.add(stored);
    } else {
      habits[index] = stored;
    }
    await _writeJsonList(_habitsFile, habits.map((item) => item.toJson()));
    return stored;
  }

  Future<void> archiveHabit(String id) async {
    final habits = await loadHabits(includeArchived: true);
    final index = habits.indexWhere((item) => item.id == id);
    if (index == -1) return;
    habits[index] = habits[index].copyWith(
      status: HabitStatus.archived,
      archivedAt: DateTime.now(),
    );
    await _writeJsonList(_habitsFile, habits.map((item) => item.toJson()));
  }

  Future<HabitCheckIn> addHabitCheckIn(HabitCheckIn checkIn) async {
    await _appendJsonLine(_checkInsFile, checkIn.toJson());
    return checkIn;
  }

  Future<List<HabitCheckIn>> loadHabitCheckIns({
    String? habitId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final checkIns = (await _readJsonLines(
      _checkInsFile,
    )).map(HabitCheckIn.fromJson);
    final filtered = checkIns.where((checkIn) {
      if (habitId != null && checkIn.habitId != habitId) return false;
      if (from != null && checkIn.checkedAt.isBefore(from)) return false;
      if (to != null && checkIn.checkedAt.isAfter(to)) return false;
      return true;
    }).toList()..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    if (limit == null || filtered.length <= limit) return filtered;
    return filtered.take(limit).toList();
  }

  Future<List<RecordTemplate>> loadTemplates() async {
    final items = await _readJsonList(_templatesFile);
    return items.map(RecordTemplate.fromJson).toList();
  }

  Future<List<TodoList>> loadTodoLists({bool includeArchived = false}) async {
    final items = await _readJsonList(_todoListsFile);
    final lists = items.map(TodoList.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (includeArchived) return lists;
    return lists.where((list) => list.status == TodoListStatus.active).toList();
  }

  Future<TodoList> saveTodoList(TodoList list) async {
    final lists = await loadTodoLists(includeArchived: true);
    final index = lists.indexWhere((item) => item.id == list.id);
    final stored = list.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      lists.add(stored);
    } else {
      lists[index] = stored;
    }
    await _writeJsonList(_todoListsFile, lists.map((item) => item.toJson()));
    return stored;
  }

  Future<void> archiveTodoList(String id) async {
    final lists = await loadTodoLists(includeArchived: true);
    final index = lists.indexWhere((item) => item.id == id);
    if (index == -1) return;
    lists[index] = lists[index].copyWith(
      status: TodoListStatus.archived,
      archivedAt: DateTime.now(),
    );
    await _writeJsonList(_todoListsFile, lists.map((item) => item.toJson()));
  }

  Future<List<TodoItem>> loadTodoItems({
    String? listId,
    bool includeArchived = false,
  }) async {
    final items =
        (await _readJsonLines(_todoItemsFile)).map(TodoItem.fromJson).where((
          item,
        ) {
          if (listId != null && item.listId != listId) return false;
          if (!includeArchived && item.status == TodoItemStatus.archived) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final statusCompare = _todoStatusRank(
            a.status,
          ).compareTo(_todoStatusRank(b.status));
          if (statusCompare != 0) return statusCompare;
          final aDue = a.dueAt;
          final bDue = b.dueAt;
          if (aDue != null && bDue != null) return aDue.compareTo(bDue);
          if (aDue != null) return -1;
          if (bDue != null) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    return items;
  }

  Future<List<TodoItem>> loadDueTodoItems({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final activeListIds = (await loadTodoLists())
        .map((list) => list.id)
        .toSet();
    final endOfToday = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
      999,
    );
    final items = await loadTodoItems();
    return items
        .where(
          (item) =>
              item.status == TodoItemStatus.open &&
              activeListIds.contains(item.listId) &&
              item.dueAt != null &&
              !item.dueAt!.isAfter(endOfToday),
        )
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  Future<TodoItem> saveTodoItem(TodoItem item) async {
    final items = await loadTodoItems(includeArchived: true);
    final index = items.indexWhere((existing) => existing.id == item.id);
    final stored = item.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      items.add(stored);
    } else {
      items[index] = stored;
    }
    await _writeJsonLines(_todoItemsFile, items.map((item) => item.toJson()));
    return stored;
  }

  Future<TodoItem?> completeTodoItem(String id, {bool completed = true}) async {
    final items = await loadTodoItems(includeArchived: true);
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return null;
    final current = items[index];
    final stored = current.copyWith(
      status: completed ? TodoItemStatus.completed : TodoItemStatus.open,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
      updatedAt: DateTime.now(),
    );
    items[index] = stored;
    await _writeJsonLines(_todoItemsFile, items.map((item) => item.toJson()));
    return stored;
  }

  Future<void> archiveTodoItem(String id) async {
    final items = await loadTodoItems(includeArchived: true);
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    items[index] = items[index].copyWith(
      status: TodoItemStatus.archived,
      updatedAt: DateTime.now(),
    );
    await _writeJsonLines(_todoItemsFile, items.map((item) => item.toJson()));
  }

  Future<void> saveTemplates(List<RecordTemplate> templates) async {
    await _writeJsonList(
      _templatesFile,
      templates.map((template) => template.toJson()),
    );
  }

  Future<RecordTemplate> saveTemplate(RecordTemplate template) async {
    final templates = await loadTemplates();
    final index = templates.indexWhere((item) => item.id == template.id);
    final stored = RecordTemplate(
      id: template.id,
      name: template.name,
      description: template.description,
      fields: template.fields,
      defaultTags: template.defaultTags,
      defaultReminderDays: template.defaultReminderDays,
      createdAt: template.createdAt,
      updatedAt: DateTime.now(),
    );
    if (index == -1) {
      templates.add(stored);
    } else {
      templates[index] = stored;
    }
    templates.sort((a, b) => a.name.compareTo(b.name));
    await saveTemplates(templates);
    return stored;
  }

  Future<LifeRecord> saveRecord(LifeRecord record) async {
    final records = await loadRecords(includeArchived: true);
    final index = records.indexWhere((item) => item.id == record.id);
    final stored = record.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      records.add(stored);
    } else {
      records[index] = stored;
    }
    await _writeJsonLines(_recordsFile, records.map((item) => item.toJson()));
    return stored;
  }

  Future<void> archiveRecord(String id) async {
    final records = await loadRecords(includeArchived: true);
    final index = records.indexWhere((item) => item.id == id);
    if (index == -1) return;
    records[index] = records[index].copyWith(
      status: LifeRecordStatus.archived,
      archivedAt: DateTime.now(),
    );
    await _writeJsonLines(_recordsFile, records.map((item) => item.toJson()));
  }

  Future<void> deleteRecord(String id) async {
    final records = await loadRecords(includeArchived: true);
    final index = records.indexWhere((item) => item.id == id);
    if (index == -1) return;
    records[index] = records[index].copyWith(
      status: LifeRecordStatus.deleted,
      archivedAt: DateTime.now(),
    );
    await _writeJsonLines(_recordsFile, records.map((item) => item.toJson()));
  }

  Future<List<LifeRecord>> loadRecords({bool includeArchived = false}) async {
    final records =
        (await _readJsonLines(_recordsFile)).map(LifeRecord.fromJson).toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (includeArchived) return records;
    return records
        .where((record) => record.status == LifeRecordStatus.active)
        .toList();
  }

  Future<List<LifeRecord>> searchRecords(LifeRecordSearchQuery query) async {
    final text = query.text?.trim().toLowerCase();
    final records = await loadRecords(includeArchived: query.includeArchived);
    final filtered = records.where((record) {
      if (query.templateId != null && record.templateId != query.templateId) {
        return false;
      }
      if (query.from != null && record.occurredAt.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && record.occurredAt.isAfter(query.to!)) {
        return false;
      }
      for (final tag in query.tags) {
        if (!record.tags.contains(tag)) return false;
      }
      if (text != null && text.isNotEmpty) {
        final haystack = [
          record.title,
          record.note ?? '',
          record.tags.join(' '),
          jsonEncode(record.fields),
        ].join(' ').toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();
    if (query.limit == null || filtered.length <= query.limit!) return filtered;
    return filtered.take(query.limit!).toList();
  }

  Future<List<Map<String, dynamic>>> _readJsonList(File file) async {
    if (!await file.exists()) return const [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return const [];
    final decoded = jsonDecode(content);
    final list = decoded is Map<String, dynamic>
        ? decoded['items'] as List<dynamic>? ?? const []
        : decoded as List<dynamic>;
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> _writeJsonList(
    File file,
    Iterable<Map<String, dynamic>> items,
  ) async {
    await file.parent.create(recursive: true);
    final payload = {'schema_version': schemaVersion, 'items': items.toList()};
    await file.writeAsString(_encoder.convert(payload));
  }

  Future<List<Map<String, dynamic>>> _readJsonLines(File file) async {
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    final items = <Map<String, dynamic>>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      items.add(Map<String, dynamic>.from(jsonDecode(trimmed) as Map));
    }
    return items;
  }

  Future<void> _appendJsonLine(File file, Map<String, dynamic> item) async {
    await file.parent.create(recursive: true);
    await file.writeAsString('${jsonEncode(item)}\n', mode: FileMode.append);
  }

  Future<void> _writeJsonLines(
    File file,
    Iterable<Map<String, dynamic>> items,
  ) async {
    await file.parent.create(recursive: true);
    final content = items.map(jsonEncode).join('\n');
    await file.writeAsString(content.isEmpty ? '' : '$content\n');
  }
}

List<RecordTemplate> defaultRecordTemplates() {
  return [
    RecordTemplate(
      id: 'fuel',
      name: '加油',
      description: '车辆加油记录',
      defaultTags: const ['car', 'fuel'],
      fields: const [
        RecordTemplateField(key: 'vehicle', label: '车辆'),
        RecordTemplateField(
          key: 'odometer',
          label: '里程表',
          type: RecordFieldType.odometer,
          unit: 'km',
        ),
        RecordTemplateField(
          key: 'liters',
          label: '升数',
          type: RecordFieldType.quantity,
          unit: 'L',
        ),
        RecordTemplateField(
          key: 'amount',
          label: '金额',
          type: RecordFieldType.money,
        ),
        RecordTemplateField(key: 'station', label: '油站'),
        RecordTemplateField(key: 'fuel_type', label: '油品'),
      ],
    ),
    RecordTemplate(
      id: 'haircut',
      name: '理发',
      description: '理发和护理记录',
      defaultTags: const ['personal', 'haircut'],
      defaultReminderDays: 30,
      fields: const [
        RecordTemplateField(key: 'shop', label: '店铺'),
        RecordTemplateField(key: 'stylist', label: '理发师'),
        RecordTemplateField(
          key: 'amount',
          label: '金额',
          type: RecordFieldType.money,
        ),
        RecordTemplateField(key: 'style_note', label: '发型备注'),
      ],
    ),
    RecordTemplate(
      id: 'car_maintenance',
      name: '汽车保养',
      description: '车辆保养和维修记录',
      defaultTags: const ['car', 'maintenance'],
      fields: const [
        RecordTemplateField(key: 'vehicle', label: '车辆'),
        RecordTemplateField(
          key: 'odometer',
          label: '里程表',
          type: RecordFieldType.odometer,
          unit: 'km',
        ),
        RecordTemplateField(key: 'service_type', label: '保养类型'),
        RecordTemplateField(key: 'parts', label: '配件'),
        RecordTemplateField(
          key: 'amount',
          label: '费用',
          type: RecordFieldType.money,
        ),
        RecordTemplateField(
          key: 'next_service_date',
          label: '下次保养日期',
          type: RecordFieldType.date,
        ),
        RecordTemplateField(
          key: 'next_service_odometer',
          label: '下次保养里程',
          type: RecordFieldType.odometer,
          unit: 'km',
        ),
      ],
    ),
  ];
}

int _todoStatusRank(TodoItemStatus status) {
  return switch (status) {
    TodoItemStatus.open => 0,
    TodoItemStatus.completed => 1,
    TodoItemStatus.archived => 2,
  };
}
