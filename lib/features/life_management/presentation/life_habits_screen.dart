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
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeHabitEditorScreen(habit: habit),
          ),
        ),
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(habit.title),
        subtitle: _HabitSubtitle(habit: habit),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '打卡',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () async {
                final repository = await ref.read(
                  lifeManagementRepositoryProvider.future,
                );
                await repository.addHabitCheckIn(
                  HabitCheckIn(habitId: habit.id),
                );
                ref.invalidate(lifeHabitCheckInsProvider(habit.id));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${habit.title} 已打卡')));
              },
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) async {
                if (value != 'archive') return;
                final confirmed = await _confirmArchive(context, habit.title);
                if (!confirmed) return;
                final repository = await ref.read(
                  lifeManagementRepositoryProvider.future,
                );
                await repository.archiveHabit(habit.id);
                ref.invalidate(lifeHabitsProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${habit.title} 已归档')));
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'archive', child: Text('归档')),
              ],
            ),
          ],
        ),
      ),
    );
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
        if (checkIns.isEmpty) return Text('$base · 暂无打卡');
        final latest = checkIns.first.checkedAt
            .toLocal()
            .toString()
            .split(' ')
            .first;
        return Text('$base · 最近打卡 $latest · ${checkIns.length} 次');
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
        '每周 ${habit.recurrence.weekdays.join(', ')}',
    };
    final target = habit.target == null
        ? ''
        : ' · ${_formatNumber(habit.target!.targetValue)} ${habit.target!.unit}';
    return '$recurrence$target';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
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
