import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habit_editor_screen.dart';

class LifeHabitsScreen extends ConsumerWidget {
  const LifeHabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(lifeHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('习惯')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LifeHabitEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: habitsAsync.when(
        data: (habits) => habits.isEmpty
            ? const _EmptyLifeState(
                icon: Icons.fact_check_outlined,
                title: '还没有习惯',
                subtitle: '点击右下角新建习惯，保存后会显示在这里。',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: habits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _HabitTile(habit: habit);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '加载习惯失败：$error',
          onRetry: () => ref.invalidate(lifeHabitsProvider),
        ),
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = habit.status == HabitStatus.paused;
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeHabitEditorScreen(habit: habit),
          ),
        ),
        leading: Icon(
          isPaused ? Icons.pause_circle_outline : Icons.fact_check_outlined,
        ),
        title: Text(habit.title),
        subtitle: _HabitSubtitle(habit: habit),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '打卡',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: isPaused
                  ? null
                  : () => _addCheckIn(
                      context,
                      ref,
                      HabitCheckIn(habitId: habit.id),
                      '${habit.title} 已打卡',
                    ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) async {
                switch (value) {
                  case 'skip':
                    await _addCheckIn(
                      context,
                      ref,
                      HabitCheckIn(
                        habitId: habit.id,
                        status: HabitCheckInStatus.skipped,
                      ),
                      '${habit.title} 已跳过',
                    );
                  case 'backfill':
                    await _backfill(context, ref);
                  case 'toggle_pause':
                    await _togglePause(context, ref);
                  case 'archive':
                    await _archive(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'skip', child: Text('跳过今天')),
                const PopupMenuItem(value: 'backfill', child: Text('补记')),
                PopupMenuItem(
                  value: 'toggle_pause',
                  child: Text(isPaused ? '恢复启用' : '暂停'),
                ),
                const PopupMenuItem(value: 'archive', child: Text('归档')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCheckIn(
    BuildContext context,
    WidgetRef ref,
    HabitCheckIn checkIn,
    String message,
  ) async {
    final repository = await ref.read(lifeManagementRepositoryProvider.future);
    await repository.addHabitCheckIn(checkIn);
    ref.invalidate(lifeHabitCheckInsProvider(habit.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backfill(BuildContext context, WidgetRef ref) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (selected == null || !context.mounted) return;
    await _addCheckIn(
      context,
      ref,
      HabitCheckIn(habitId: habit.id, checkedAt: selected),
      '${habit.title} 已补记',
    );
  }

  Future<void> _togglePause(BuildContext context, WidgetRef ref) async {
    final service = await ref.read(lifeManagementServiceProvider.future);
    final nextStatus = habit.status == HabitStatus.paused
        ? HabitStatus.active
        : HabitStatus.paused;
    await service.saveHabit(habit.copyWith(status: nextStatus));
    ref.invalidate(lifeHabitsProvider);
    if (!context.mounted) return;
    final message = nextStatus == HabitStatus.paused ? '已暂停' : '已恢复启用';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${habit.title} $message')));
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmArchive(context, habit.title);
    if (!confirmed) return;
    final service = await ref.read(lifeManagementServiceProvider.future);
    await service.archiveHabit(habit.id);
    ref.invalidate(lifeHabitsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${habit.title} 已归档')));
  }

  Future<bool> _confirmArchive(BuildContext context, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档习惯'),
        content: Text('确定归档“$title”？历史打卡会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _HabitSubtitle extends ConsumerWidget {
  const _HabitSubtitle({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInsAsync = ref.watch(lifeHabitCheckInsProvider(habit.id));
    final base = _habitSubtitle(habit);
    return checkInsAsync.when(
      data: (checkIns) {
        final status = habit.status == HabitStatus.paused ? ' · 已暂停' : '';
        if (checkIns.isEmpty) return Text('$base$status · 暂无打卡');
        final latest = checkIns.first.checkedAt
            .toLocal()
            .toString()
            .split(' ')
            .first;
        final stats = _HabitStats.from(habit, checkIns);
        return Text(
          '$base$status · 最近 $latest · 连续 ${stats.streakDays} 天 · '
          '7天 ${stats.completed7}/${stats.expected7} · '
          '30天 ${stats.completed30}/${stats.expected30}',
        );
      },
      loading: () => Text(base),
      error: (_, _) => Text(base),
    );
  }

  String _habitSubtitle(Habit habit) {
    final recurrence = switch (habit.recurrence.type) {
      HabitRecurrenceType.daily => '每天',
      HabitRecurrenceType.weekly => '每周',
      HabitRecurrenceType.selectedWeekdays =>
        '每周 ${habit.recurrence.weekdays.map(_weekdayLabel).join('、')}',
    };
    final target = habit.target == null
        ? ''
        : ' · ${_formatNumber(habit.target!.targetValue)} ${habit.target!.unit}';
    final reminder =
        habit.reminder?.enabled == true &&
            habit.reminder?.hour != null &&
            habit.reminder?.minute != null
        ? ' · 提醒 ${_twoDigits(habit.reminder!.hour!)}:${_twoDigits(habit.reminder!.minute!)}'
        : '';
    return '$recurrence$target$reminder';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _HabitStats {
  const _HabitStats({
    required this.streakDays,
    required this.completed7,
    required this.expected7,
    required this.completed30,
    required this.expected30,
  });

  final int streakDays;
  final int completed7;
  final int expected7;
  final int completed30;
  final int expected30;

  factory _HabitStats.from(Habit habit, List<HabitCheckIn> checkIns) {
    final completedDays = <DateTime>{};
    final skippedDays = <DateTime>{};
    for (final checkIn in checkIns) {
      final day = _dayOnly(checkIn.checkedAt);
      if (checkIn.status == HabitCheckInStatus.completed ||
          checkIn.status == HabitCheckInStatus.partial) {
        completedDays.add(day);
      } else if (checkIn.status == HabitCheckInStatus.skipped) {
        skippedDays.add(day);
      }
    }
    final today = _dayOnly(DateTime.now());
    final expected7 = _expectedDays(habit, today, 7);
    final expected30 = _expectedDays(habit, today, 30);
    var streak = 0;
    for (var day = today; ; day = day.subtract(const Duration(days: 1))) {
      if (!_isExpectedDay(habit, day)) continue;
      if (completedDays.contains(day)) {
        streak++;
        continue;
      }
      break;
    }
    return _HabitStats(
      streakDays: streak,
      completed7: expected7.where(completedDays.contains).length,
      expected7: expected7.where((day) => !skippedDays.contains(day)).length,
      completed30: expected30.where(completedDays.contains).length,
      expected30: expected30.where((day) => !skippedDays.contains(day)).length,
    );
  }

  static List<DateTime> _expectedDays(Habit habit, DateTime today, int days) {
    return [
      for (var offset = 0; offset < days; offset++)
        today.subtract(Duration(days: offset)),
    ].where((day) => _isExpectedDay(habit, day)).toList();
  }
}

DateTime _dayOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _isExpectedDay(Habit habit, DateTime day) {
  return switch (habit.recurrence.type) {
    HabitRecurrenceType.daily => true,
    HabitRecurrenceType.weekly => day.weekday == habit.createdAt.weekday,
    HabitRecurrenceType.selectedWeekdays =>
      habit.recurrence.weekdays.isEmpty ||
          habit.recurrence.weekdays.contains(day.weekday),
  };
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '周$weekday',
  };
}

class _EmptyLifeState extends StatelessWidget {
  const _EmptyLifeState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
