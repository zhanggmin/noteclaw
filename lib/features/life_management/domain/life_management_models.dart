import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum HabitStatus { active, paused, archived }

enum HabitRecurrenceType { daily, weekly, selectedWeekdays }

enum HabitCheckInStatus { completed, partial, skipped, missed }

enum LifeRecordStatus { active, archived, deleted }

enum RecordFieldType { text, number, money, date, odometer, quantity }

enum ReminderKind { once, daily, weekly, monthly }

String _newId() => _uuid.v4();

DateTime _dateFromJson(Object? value, {DateTime? fallback}) {
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return fallback ?? DateTime.now();
}

DateTime? _nullableDateFromJson(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return null;
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList();
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  return fallback;
}

class HabitTarget {
  final double targetValue;
  final String unit;

  const HabitTarget({required this.targetValue, required this.unit});

  Map<String, dynamic> toJson() => {'target_value': targetValue, 'unit': unit};

  factory HabitTarget.fromJson(Map<String, dynamic> json) => HabitTarget(
    targetValue: (json['target_value'] as num?)?.toDouble() ?? 1,
    unit: json['unit'] as String? ?? 'times',
  );
}

class HabitRecurrence {
  final HabitRecurrenceType type;
  final List<int> weekdays;
  final int intervalDays;

  const HabitRecurrence({
    this.type = HabitRecurrenceType.daily,
    this.weekdays = const [],
    this.intervalDays = 1,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (weekdays.isNotEmpty) 'weekdays': weekdays,
    'interval_days': intervalDays,
  };

  factory HabitRecurrence.fromJson(Map<String, dynamic> json) =>
      HabitRecurrence(
        type: _enumByName(
          HabitRecurrenceType.values,
          json['type'],
          HabitRecurrenceType.daily,
        ),
        weekdays:
            (json['weekdays'] as List?)
                ?.whereType<num>()
                .map((n) => n.toInt())
                .toList() ??
            const [],
        intervalDays: json['interval_days'] as int? ?? 1,
      );
}

class ReminderRule {
  final String id;
  final bool enabled;
  final ReminderKind kind;
  final DateTime? scheduledAt;
  final int? hour;
  final int? minute;

  ReminderRule({
    String? id,
    this.enabled = true,
    this.kind = ReminderKind.once,
    this.scheduledAt,
    this.hour,
    this.minute,
  }) : id = id ?? _newId();

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'kind': kind.name,
    if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
    if (hour != null) 'hour': hour,
    if (minute != null) 'minute': minute,
  };

  factory ReminderRule.fromJson(Map<String, dynamic> json) => ReminderRule(
    id: json['id'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    kind: _enumByName(ReminderKind.values, json['kind'], ReminderKind.once),
    scheduledAt: _nullableDateFromJson(json['scheduled_at']),
    hour: json['hour'] as int?,
    minute: json['minute'] as int?,
  );
}

class Habit {
  final String id;
  final String title;
  final String? note;
  final List<String> tags;
  final HabitStatus status;
  final HabitRecurrence recurrence;
  final HabitTarget? target;
  final ReminderRule? reminder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  Habit({
    String? id,
    required this.title,
    this.note,
    this.tags = const [],
    this.status = HabitStatus.active,
    this.recurrence = const HabitRecurrence(),
    this.target,
    this.reminder,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.archivedAt,
  }) : id = id ?? _newId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Habit copyWith({
    String? title,
    String? note,
    List<String>? tags,
    HabitStatus? status,
    HabitRecurrence? recurrence,
    HabitTarget? target,
    ReminderRule? reminder,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      recurrence: recurrence ?? this.recurrence,
      target: target ?? this.target,
      reminder: reminder ?? this.reminder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (note != null) 'note': note,
    if (tags.isNotEmpty) 'tags': tags,
    'status': status.name,
    'recurrence': recurrence.toJson(),
    if (target != null) 'target': target!.toJson(),
    if (reminder != null) 'reminder': reminder!.toJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
  };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    note: json['note'] as String?,
    tags: _stringList(json['tags']),
    status: _enumByName(HabitStatus.values, json['status'], HabitStatus.active),
    recurrence: HabitRecurrence.fromJson(_map(json['recurrence'])),
    target: json['target'] == null
        ? null
        : HabitTarget.fromJson(_map(json['target'])),
    reminder: json['reminder'] == null
        ? null
        : ReminderRule.fromJson(_map(json['reminder'])),
    createdAt: _dateFromJson(json['created_at']),
    updatedAt: _dateFromJson(json['updated_at']),
    archivedAt: _nullableDateFromJson(json['archived_at']),
  );
}

class HabitCheckIn {
  final String id;
  final String habitId;
  final DateTime checkedAt;
  final HabitCheckInStatus status;
  final double? value;
  final String? note;
  final DateTime createdAt;

  HabitCheckIn({
    String? id,
    required this.habitId,
    DateTime? checkedAt,
    this.status = HabitCheckInStatus.completed,
    this.value,
    this.note,
    DateTime? createdAt,
  }) : id = id ?? _newId(),
       checkedAt = checkedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'habit_id': habitId,
    'checked_at': checkedAt.toIso8601String(),
    'status': status.name,
    if (value != null) 'value': value,
    if (note != null) 'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  factory HabitCheckIn.fromJson(Map<String, dynamic> json) => HabitCheckIn(
    id: json['id'] as String?,
    habitId: json['habit_id'] as String? ?? '',
    checkedAt: _dateFromJson(json['checked_at']),
    status: _enumByName(
      HabitCheckInStatus.values,
      json['status'],
      HabitCheckInStatus.completed,
    ),
    value: (json['value'] as num?)?.toDouble(),
    note: json['note'] as String?,
    createdAt: _dateFromJson(json['created_at']),
  );
}

class RecordTemplateField {
  final String key;
  final String label;
  final RecordFieldType type;
  final bool required;
  final String? unit;

  const RecordTemplateField({
    required this.key,
    required this.label,
    this.type = RecordFieldType.text,
    this.required = false,
    this.unit,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'required': required,
    if (unit != null) 'unit': unit,
  };

  factory RecordTemplateField.fromJson(Map<String, dynamic> json) =>
      RecordTemplateField(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        type: _enumByName(
          RecordFieldType.values,
          json['type'],
          RecordFieldType.text,
        ),
        required: json['required'] as bool? ?? false,
        unit: json['unit'] as String?,
      );
}

class RecordTemplate {
  final String id;
  final String name;
  final String? description;
  final List<RecordTemplateField> fields;
  final List<String> defaultTags;
  final int? defaultReminderDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecordTemplate({
    required this.id,
    required this.name,
    this.description,
    this.fields = const [],
    this.defaultTags = const [],
    this.defaultReminderDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'fields': fields.map((field) => field.toJson()).toList(),
    if (defaultTags.isNotEmpty) 'default_tags': defaultTags,
    if (defaultReminderDays != null)
      'default_reminder_days': defaultReminderDays,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory RecordTemplate.fromJson(Map<String, dynamic> json) => RecordTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    fields:
        (json['fields'] as List?)
            ?.map((e) => RecordTemplateField.fromJson(_map(e)))
            .toList() ??
        const [],
    defaultTags: _stringList(json['default_tags']),
    defaultReminderDays: json['default_reminder_days'] as int?,
    createdAt: _dateFromJson(json['created_at']),
    updatedAt: _dateFromJson(json['updated_at']),
  );
}

class LifeRecord {
  final String id;
  final String templateId;
  final String title;
  final String? note;
  final List<String> tags;
  final Map<String, dynamic> fields;
  final LifeRecordStatus status;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final ReminderRule? reminder;

  LifeRecord({
    String? id,
    required this.templateId,
    required this.title,
    this.note,
    this.tags = const [],
    this.fields = const {},
    this.status = LifeRecordStatus.active,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.archivedAt,
    this.reminder,
  }) : id = id ?? _newId(),
       occurredAt = occurredAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  LifeRecord copyWith({
    String? templateId,
    String? title,
    String? note,
    List<String>? tags,
    Map<String, dynamic>? fields,
    LifeRecordStatus? status,
    DateTime? occurredAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    ReminderRule? reminder,
  }) {
    return LifeRecord(
      id: id,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      fields: fields ?? this.fields,
      status: status ?? this.status,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archivedAt: archivedAt ?? this.archivedAt,
      reminder: reminder ?? this.reminder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'template_id': templateId,
    'title': title,
    if (note != null) 'note': note,
    if (tags.isNotEmpty) 'tags': tags,
    if (fields.isNotEmpty) 'fields': fields,
    'status': status.name,
    'occurred_at': occurredAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    if (reminder != null) 'reminder': reminder!.toJson(),
  };

  factory LifeRecord.fromJson(Map<String, dynamic> json) => LifeRecord(
    id: json['id'] as String?,
    templateId: json['template_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    note: json['note'] as String?,
    tags: _stringList(json['tags']),
    fields: _map(json['fields']),
    status: _enumByName(
      LifeRecordStatus.values,
      json['status'],
      LifeRecordStatus.active,
    ),
    occurredAt: _dateFromJson(json['occurred_at']),
    createdAt: _dateFromJson(json['created_at']),
    updatedAt: _dateFromJson(json['updated_at']),
    archivedAt: _nullableDateFromJson(json['archived_at']),
    reminder: json['reminder'] == null
        ? null
        : ReminderRule.fromJson(_map(json['reminder'])),
  );
}
