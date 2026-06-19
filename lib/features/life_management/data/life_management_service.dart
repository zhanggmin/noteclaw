import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/services/notification_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('flutterclaw.life_management_service');

abstract class LifeReminderScheduler {
  Future<void> cancelNotification(int id);

  Future<void> scheduleOneOffReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  });

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  });

  Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  });
}

class NotificationLifeReminderScheduler implements LifeReminderScheduler {
  NotificationLifeReminderScheduler({required NotificationService service})
    : _service = service;

  final NotificationService _service;

  @override
  Future<void> cancelNotification(int id) => _service.cancelNotification(id);

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) {
    return _service.scheduleDailyReminder(
      id: id,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
      payload: payload,
    );
  }

  @override
  Future<void> scheduleOneOffReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) {
    return _service.scheduleOneOffReminder(
      id: id,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: payload,
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
  }) {
    return _service.scheduleWeeklyReminder(
      id: id,
      title: title,
      body: body,
      weekday: weekday,
      hour: hour,
      minute: minute,
      payload: payload,
    );
  }
}

class LifeManagementService {
  LifeManagementService({
    required LifeManagementRepository repository,
    required LifeReminderScheduler reminderScheduler,
  }) : _repository = repository,
       _reminderScheduler = reminderScheduler;

  final LifeManagementRepository _repository;
  final LifeReminderScheduler _reminderScheduler;

  Future<Habit> saveHabit(Habit habit) async {
    final stored = await _repository.saveHabit(habit);
    await syncHabitReminder(stored);
    return stored;
  }

  Future<void> archiveHabit(String id) async {
    await _repository.archiveHabit(id);
    await cancelHabitReminder(id);
  }

  Future<LifeRecord> saveRecord(LifeRecord record) async {
    final stored = await _repository.saveRecord(record);
    await syncRecordReminder(stored);
    return stored;
  }

  Future<TodoItem> saveTodoItem(TodoItem item) async {
    final stored = await _repository.saveTodoItem(item);
    await syncTodoReminder(stored);
    return stored;
  }

  Future<void> archiveTodoList(String id) async {
    final items = await _repository.loadTodoItems(
      listId: id,
      includeArchived: true,
    );
    await _repository.archiveTodoList(id);
    for (final item in items) {
      await cancelTodoReminder(item.id);
    }
  }

  Future<TodoItem?> completeTodoItem(String id, {bool completed = true}) async {
    final stored = await _repository.completeTodoItem(id, completed: completed);
    if (stored == null) return null;
    if (completed) {
      await cancelTodoReminder(id);
    } else {
      await syncTodoReminder(stored);
    }
    return stored;
  }

  Future<void> archiveTodoItem(String id) async {
    await _repository.archiveTodoItem(id);
    await cancelTodoReminder(id);
  }

  Future<void> archiveRecord(String id) async {
    await _repository.archiveRecord(id);
    await cancelRecordReminder(id);
  }

  Future<void> deleteRecord(String id) async {
    await _repository.deleteRecord(id);
    await cancelRecordReminder(id);
  }

  Future<void> syncHabitReminder(Habit habit) async {
    await cancelHabitReminder(habit.id);
    final reminder = habit.reminder;
    if (habit.status != HabitStatus.active ||
        reminder == null ||
        !reminder.enabled ||
        reminder.hour == null ||
        reminder.minute == null) {
      return;
    }

    try {
      switch (habit.recurrence.type) {
        case HabitRecurrenceType.daily:
          await _reminderScheduler.scheduleDailyReminder(
            id: _habitReminderId(habit.id),
            title: habit.title,
            body: '该打卡了',
            hour: reminder.hour!,
            minute: reminder.minute!,
            payload: 'life:habit:${habit.id}',
          );
        case HabitRecurrenceType.weekly:
          await _reminderScheduler.scheduleWeeklyReminder(
            id: _habitReminderId(habit.id),
            title: habit.title,
            body: '该打卡了',
            weekday: habit.createdAt.weekday,
            hour: reminder.hour!,
            minute: reminder.minute!,
            payload: 'life:habit:${habit.id}',
          );
        case HabitRecurrenceType.selectedWeekdays:
          final weekdays = habit.recurrence.weekdays.isEmpty
              ? const [DateTime.monday]
              : habit.recurrence.weekdays;
          for (final weekday in weekdays) {
            await _reminderScheduler.scheduleWeeklyReminder(
              id: _habitReminderId(habit.id, weekday: weekday),
              title: habit.title,
              body: '该打卡了',
              weekday: weekday,
              hour: reminder.hour!,
              minute: reminder.minute!,
              payload: 'life:habit:${habit.id}',
            );
          }
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed syncing habit reminder ${habit.id}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> syncRecordReminder(LifeRecord record) async {
    await cancelRecordReminder(record.id);
    final reminder = record.reminder;
    if (record.status != LifeRecordStatus.active ||
        reminder == null ||
        !reminder.enabled ||
        reminder.scheduledAt == null) {
      return;
    }

    try {
      await _reminderScheduler.scheduleOneOffReminder(
        id: _recordReminderId(record.id),
        title: record.title,
        body: '后续提醒',
        scheduledAt: reminder.scheduledAt!,
        payload: 'life:record:${record.id}',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed syncing record reminder ${record.id}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> syncTodoReminder(TodoItem item) async {
    await cancelTodoReminder(item.id);
    if (item.status != TodoItemStatus.open || item.dueAt == null) {
      return;
    }

    try {
      await _reminderScheduler.scheduleOneOffReminder(
        id: _todoReminderId(item.id),
        title: item.title,
        body: '待办截止提醒',
        scheduledAt: item.dueAt!,
        payload: 'life:todo:${item.id}',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed syncing todo reminder ${item.id}',
        error,
        stackTrace,
      );
    }
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await _reminderScheduler.cancelNotification(_habitReminderId(habitId));
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _reminderScheduler.cancelNotification(
        _habitReminderId(habitId, weekday: weekday),
      );
    }
  }

  Future<void> cancelRecordReminder(String recordId) async {
    await _reminderScheduler.cancelNotification(_recordReminderId(recordId));
  }

  Future<void> cancelTodoReminder(String todoId) async {
    await _reminderScheduler.cancelNotification(_todoReminderId(todoId));
  }
}

int _habitReminderId(String habitId, {int? weekday}) {
  return _stableNotificationId('life:habit:$habitId:${weekday ?? 0}');
}

int _recordReminderId(String recordId) {
  return _stableNotificationId('life:record:$recordId');
}

int _todoReminderId(String todoId) {
  return _stableNotificationId('life:todo:$todoId');
}

int _stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 100000 + (hash % 800000);
}
