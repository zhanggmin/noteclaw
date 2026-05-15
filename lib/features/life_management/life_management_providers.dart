import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/core/app_providers.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';

final lifeManagementRepositoryProvider =
    FutureProvider<LifeManagementRepository>((ref) async {
      final configDir = await ref.watch(configManagerProvider).configDir;
      final repository = LifeManagementRepository(
        Directory('$configDir/life_management'),
      );
      await repository.initialize();
      return repository;
    });

final lifeManagementServiceProvider = FutureProvider<LifeManagementService>((
  ref,
) async {
  final repository = await ref.watch(lifeManagementRepositoryProvider.future);
  return LifeManagementService(
    repository: repository,
    reminderScheduler: NotificationLifeReminderScheduler(
      service: ref.watch(notificationServiceProvider),
    ),
  );
});

final lifeHabitsProvider = FutureProvider<List<Habit>>((ref) async {
  final repository = await ref.watch(lifeManagementRepositoryProvider.future);
  return repository.loadHabits();
});

final lifeRecordsProvider = FutureProvider<List<LifeRecord>>((ref) async {
  final repository = await ref.watch(lifeManagementRepositoryProvider.future);
  return repository.loadRecords();
});

final lifeRecordTemplatesProvider = FutureProvider<List<RecordTemplate>>((
  ref,
) async {
  final repository = await ref.watch(lifeManagementRepositoryProvider.future);
  return repository.loadTemplates();
});

final lifeHabitCheckInsProvider =
    FutureProvider.family<List<HabitCheckIn>, String>((ref, habitId) async {
      final repository = await ref.watch(
        lifeManagementRepositoryProvider.future,
      );
      final from = DateTime.now().subtract(const Duration(days: 45));
      return repository.loadHabitCheckIns(habitId: habitId, from: from);
    });
