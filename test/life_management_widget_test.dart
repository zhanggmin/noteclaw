import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habits_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_home_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_records_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_todo_list_detail_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_todos_screen.dart';

void main() {
  testWidgets('life home renders today habits and recent records', (
    tester,
  ) async {
    final habit = Habit(
      id: 'habit-1',
      title: '晨跑',
      recurrence: const HabitRecurrence(type: HabitRecurrenceType.daily),
      reminder: ReminderRule(kind: ReminderKind.daily, hour: 7, minute: 30),
      createdAt: DateTime(2026, 5, 14),
    );
    final template = RecordTemplate(id: 'fuel', name: '加油');
    final record = LifeRecord(
      id: 'record-1',
      templateId: 'fuel',
      title: '今天加油',
      occurredAt: DateTime(2026, 5, 14),
    );
    final todoList = TodoList(id: 'todo-list-1', title: '周末要做的10件事');
    final todo = TodoItem(
      id: 'todo-1',
      listId: 'todo-list-1',
      title: '整理书桌',
      dueAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeHabitsProvider.overrideWith((ref) async => [habit]),
          lifeRecordsProvider.overrideWith((ref) async => [record]),
          lifeRecordTemplatesProvider.overrideWith((ref) async => [template]),
          lifeDueTodoItemsProvider.overrideWith((ref) async => [todo]),
          lifeTodoListsProvider.overrideWith((ref) async => [todoList]),
          lifeTodoItemsAllProvider.overrideWith((ref) async => [todo]),
          lifeHabitCheckInsProvider.overrideWith((ref, habitId) async => []),
        ],
        child: const MaterialApp(home: LifeHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('今日习惯'), findsOneWidget);
    expect(find.text('晨跑'), findsOneWidget);
    expect(find.text('今日待办'), findsOneWidget);
    expect(find.text('整理书桌'), findsOneWidget);
    expect(find.text('最近记录'), findsOneWidget);
    expect(find.text('今天加油'), findsOneWidget);
  });

  testWidgets('habits screen renders reminder summary', (tester) async {
    final habit = Habit(
      id: 'habit-1',
      title: '喝水',
      reminder: ReminderRule(kind: ReminderKind.daily, hour: 9, minute: 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeHabitsProvider.overrideWith((ref) async => [habit]),
          lifeHabitCheckInsProvider.overrideWith((ref, habitId) async => []),
        ],
        child: const MaterialApp(home: LifeHabitsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('喝水'), findsOneWidget);
    expect(find.textContaining('提醒 09:05'), findsOneWidget);
  });

  testWidgets('habits screen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lifeHabitsProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: LifeHabitsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('还没有习惯'), findsOneWidget);
    expect(find.text('新建'), findsOneWidget);
  });

  testWidgets('records screen renders template empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeRecordsProvider.overrideWith((ref) async => []),
          lifeRecordTemplatesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: LifeRecordsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('还没有模板'), findsOneWidget);
    expect(find.text('新建模板'), findsOneWidget);
  });

  testWidgets('todos screen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeTodoListsProvider.overrideWith((ref) async => []),
          lifeTodoItemsAllProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: LifeTodosScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('还没有待办主题'), findsOneWidget);
    expect(find.text('新建主题'), findsOneWidget);
  });

  testWidgets('todos screen renders list summary', (tester) async {
    final list = TodoList(id: 'todo-list-1', title: '周末要做的10件事');
    final items = [
      TodoItem(id: 'todo-1', listId: list.id, title: '整理书桌'),
      TodoItem(
        id: 'todo-2',
        listId: list.id,
        title: '洗衣服',
        status: TodoItemStatus.completed,
        completedAt: DateTime(2026, 5, 16),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeTodoListsProvider.overrideWith((ref) async => [list]),
          lifeTodoItemsAllProvider.overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: LifeTodosScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('周末要做的10件事'), findsOneWidget);
    expect(find.text('未完成 1 · 已完成 1 · 总计 2'), findsOneWidget);
  });

  testWidgets('todo detail opens bulk add sheet', (tester) async {
    final list = TodoList(id: 'todo-list-1', title: '周末要做的10件事');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeTodoItemsProvider.overrideWith((ref, listId) async => []),
        ],
        child: MaterialApp(home: LifeTodoListDetailScreen(list: list)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('批量新增'));
    await tester.pumpAndSettle();

    expect(find.text('批量新增待办'), findsOneWidget);
    expect(find.text('新增 0 条待办'), findsOneWidget);
  });
}
