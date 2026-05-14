import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';

void main() {
  late Directory tempDir;
  late LifeManagementRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('life_management_test_');
    repository = LifeManagementRepository(tempDir);
    await repository.initialize();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('initializes default record templates idempotently', () async {
    final first = await repository.ensureDefaultTemplates();
    final second = await repository.ensureDefaultTemplates();

    expect(
      first.map((template) => template.id),
      containsAll(['fuel', 'haircut', 'car_maintenance']),
    );
    expect(second.length, first.length);
  });

  test('saves custom record templates without dropping defaults', () async {
    await repository.saveTemplate(
      RecordTemplate(
        id: 'custom_subscription',
        name: '订阅',
        fields: const [
          RecordTemplateField(key: 'service', label: '服务'),
          RecordTemplateField(key: 'amount', label: '金额'),
        ],
      ),
    );

    final templates = await repository.loadTemplates();

    expect(
      templates.map((template) => template.id),
      contains('custom_subscription'),
    );
    expect(templates.map((template) => template.id), contains('fuel'));
  });

  test('serializes and restores habit with recurrence and reminder', () {
    final habit = Habit(
      id: 'habit-1',
      title: '跑步',
      tags: const ['health'],
      recurrence: const HabitRecurrence(
        type: HabitRecurrenceType.selectedWeekdays,
        weekdays: [1, 3, 5],
      ),
      target: const HabitTarget(targetValue: 5, unit: 'km'),
      reminder: ReminderRule(kind: ReminderKind.weekly, hour: 7, minute: 30),
      createdAt: DateTime.utc(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 2),
    );

    final restored = Habit.fromJson(habit.toJson());

    expect(restored.id, 'habit-1');
    expect(restored.title, '跑步');
    expect(restored.recurrence.type, HabitRecurrenceType.selectedWeekdays);
    expect(restored.recurrence.weekdays, [1, 3, 5]);
    expect(restored.target?.unit, 'km');
    expect(restored.reminder?.hour, 7);
  });

  test('saves habits and appends check-ins', () async {
    final habit = await repository.saveHabit(Habit(title: '喝水'));
    await repository.addHabitCheckIn(
      HabitCheckIn(
        habitId: habit.id,
        status: HabitCheckInStatus.completed,
        checkedAt: DateTime.utc(2026, 5, 13, 8),
      ),
    );

    final habits = await repository.loadHabits();
    final checkIns = await repository.loadHabitCheckIns(habitId: habit.id);

    expect(habits.single.title, '喝水');
    expect(checkIns.single.habitId, habit.id);
    expect(checkIns.single.status, HabitCheckInStatus.completed);
  });

  test('archives habits without deleting check-in history', () async {
    final habit = await repository.saveHabit(Habit(title: '早睡'));
    await repository.addHabitCheckIn(HabitCheckIn(habitId: habit.id));
    await repository.archiveHabit(habit.id);

    final activeHabits = await repository.loadHabits();
    final allHabits = await repository.loadHabits(includeArchived: true);
    final checkIns = await repository.loadHabitCheckIns(habitId: habit.id);

    expect(activeHabits, isEmpty);
    expect(allHabits.single.status, HabitStatus.archived);
    expect(checkIns, hasLength(1));
  });

  test('saves, searches, archives, and soft-deletes records', () async {
    final record = await repository.saveRecord(
      LifeRecord(
        templateId: 'fuel',
        title: '今天加油',
        tags: const ['car'],
        occurredAt: DateTime.utc(2026, 5, 13),
        fields: const {'vehicle': 'Model 3', 'amount': 320, 'liters': 43},
      ),
    );

    final found = await repository.searchRecords(
      const LifeRecordSearchQuery(templateId: 'fuel', text: 'model 3'),
    );
    expect(found.single.id, record.id);

    await repository.archiveRecord(record.id);
    expect(await repository.loadRecords(), isEmpty);
    expect(await repository.loadRecords(includeArchived: true), hasLength(1));

    await repository.deleteRecord(record.id);
    final all = await repository.loadRecords(includeArchived: true);
    expect(all.single.status, LifeRecordStatus.deleted);
  });
}
