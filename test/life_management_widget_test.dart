import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habits_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_home_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_records_screen.dart';

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lifeHabitsProvider.overrideWith((ref) async => [habit]),
          lifeRecordsProvider.overrideWith((ref) async => [record]),
          lifeRecordTemplatesProvider.overrideWith((ref) async => [template]),
          lifeHabitCheckInsProvider.overrideWith((ref, habitId) async => []),
        ],
        child: const MaterialApp(home: LifeHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('今日习惯'), findsOneWidget);
    expect(find.text('晨跑'), findsOneWidget);
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
}
