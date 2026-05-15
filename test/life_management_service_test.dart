import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';

void main() {
  late Directory tempDir;
  late LifeManagementRepository repository;
  late _FakeReminderScheduler scheduler;
  late LifeManagementService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('life_management_service_');
    repository = LifeManagementRepository(tempDir);
    await repository.initialize();
    scheduler = _FakeReminderScheduler();
    service = LifeManagementService(
      repository: repository,
      reminderScheduler: scheduler,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saving habit schedules daily reminder', () async {
    await service.saveHabit(
      Habit(
        id: 'habit-1',
        title: '喝水',
        reminder: ReminderRule(kind: ReminderKind.daily, hour: 9, minute: 30),
      ),
    );

    expect(scheduler.dailySchedules, hasLength(1));
    expect(scheduler.dailySchedules.single.title, '喝水');
    expect(scheduler.dailySchedules.single.hour, 9);
    expect(scheduler.dailySchedules.single.minute, 30);
  });

  test('saving selected-weekday habit schedules weekly reminders', () async {
    await service.saveHabit(
      Habit(
        id: 'habit-1',
        title: '跑步',
        recurrence: const HabitRecurrence(
          type: HabitRecurrenceType.selectedWeekdays,
          weekdays: [DateTime.monday, DateTime.friday],
        ),
        reminder: ReminderRule(kind: ReminderKind.weekly, hour: 7, minute: 0),
      ),
    );

    expect(scheduler.weeklySchedules, hasLength(2));
    expect(
      scheduler.weeklySchedules.map((item) => item.weekday),
      containsAll([DateTime.monday, DateTime.friday]),
    );
  });

  test('archiving habit cancels reminder IDs', () async {
    final habit = await service.saveHabit(
      Habit(
        id: 'habit-1',
        title: '喝水',
        reminder: ReminderRule(kind: ReminderKind.daily, hour: 9, minute: 30),
      ),
    );
    scheduler.clear();

    await service.archiveHabit(habit.id);

    expect(scheduler.cancelledIds, hasLength(8));
  });

  test('saving record schedules one-off reminder', () async {
    final scheduledAt = DateTime(2026, 6, 13, 9);

    await service.saveRecord(
      LifeRecord(
        id: 'record-1',
        templateId: 'haircut',
        title: '理发',
        reminder: ReminderRule(
          kind: ReminderKind.once,
          scheduledAt: scheduledAt,
        ),
      ),
    );

    expect(scheduler.oneOffSchedules, hasLength(1));
    expect(scheduler.oneOffSchedules.single.title, '理发');
    expect(scheduler.oneOffSchedules.single.scheduledAt, scheduledAt);
  });
}

class _FakeReminderScheduler implements LifeReminderScheduler {
  final cancelledIds = <int>[];
  final oneOffSchedules = <_OneOffSchedule>[];
  final dailySchedules = <_DailySchedule>[];
  final weeklySchedules = <_WeeklySchedule>[];

  void clear() {
    cancelledIds.clear();
    oneOffSchedules.clear();
    dailySchedules.clear();
    weeklySchedules.clear();
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    dailySchedules.add(
      _DailySchedule(title: title, hour: hour, minute: minute),
    );
  }

  @override
  Future<void> scheduleOneOffReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    oneOffSchedules.add(
      _OneOffSchedule(title: title, scheduledAt: scheduledAt),
    );
  }

  @override
  Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    weeklySchedules.add(
      _WeeklySchedule(
        title: title,
        weekday: weekday,
        hour: hour,
        minute: minute,
      ),
    );
  }
}

class _OneOffSchedule {
  const _OneOffSchedule({required this.title, required this.scheduledAt});

  final String title;
  final DateTime scheduledAt;
}

class _DailySchedule {
  const _DailySchedule({
    required this.title,
    required this.hour,
    required this.minute,
  });

  final String title;
  final int hour;
  final int minute;
}

class _WeeklySchedule {
  const _WeeklySchedule({
    required this.title,
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final String title;
  final int weekday;
  final int hour;
  final int minute;
}
