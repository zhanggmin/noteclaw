import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habit_editor_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habits_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_record_editor_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_record_template_editor_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_records_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_template_records_screen.dart';

class LifeHomeScreen extends ConsumerWidget {
  const LifeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(lifeHabitsProvider);
    final recordsAsync = ref.watch(lifeRecordsProvider);
    final templatesAsync = ref.watch(lifeRecordTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Life')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Life 管理',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '今日习惯、最近记录和快捷创建。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _QuickActions(templatesAsync: templatesAsync),
          const SizedBox(height: 16),
          habitsAsync.when(
            data: (habits) => _TodayHabitsSection(habits: habits),
            loading: () => const _LoadingSection(title: '今日习惯'),
            error: (error, _) => _InlineError(
              title: '今日习惯',
              message: '$error',
              onRetry: () => ref.invalidate(lifeHabitsProvider),
            ),
          ),
          const SizedBox(height: 16),
          recordsAsync.when(
            data: (records) => templatesAsync.when(
              data: (templates) =>
                  _RecentRecordsSection(records: records, templates: templates),
              loading: () => const _LoadingSection(title: '最近记录'),
              error: (error, _) => _InlineError(
                title: '最近记录',
                message: '$error',
                onRetry: () => ref.invalidate(lifeRecordTemplatesProvider),
              ),
            ),
            loading: () => const _LoadingSection(title: '最近记录'),
            error: (error, _) => _InlineError(
              title: '最近记录',
              message: '$error',
              onRetry: () => ref.invalidate(lifeRecordsProvider),
            ),
          ),
          const SizedBox(height: 16),
          _LifeSectionTile(
            icon: Icons.fact_check_outlined,
            title: '习惯',
            subtitle: '创建习惯、打卡、跳过和查看基础统计',
            color: theme.colorScheme.primaryContainer,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LifeHabitsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _LifeSectionTile(
            icon: Icons.receipt_long_outlined,
            title: '记录',
            subtitle: '记录加油、理发、汽车保养等日常事件',
            color: theme.colorScheme.secondaryContainer,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LifeRecordsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _LifeSectionTile(
            icon: Icons.flag_outlined,
            title: '目标',
            subtitle: '后续阶段接入目标、计划和复盘',
            color: theme.colorScheme.tertiaryContainer,
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('目标功能将在后续阶段接入')));
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.templatesAsync});

  final AsyncValue<List<RecordTemplate>> templatesAsync;

  @override
  Widget build(BuildContext context) {
    final templates = templatesAsync.value ?? const <RecordTemplate>[];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LifeHabitEditorScreen()),
          ),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('新建习惯'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LifeRecordTemplateEditorScreen(),
            ),
          ),
          icon: const Icon(Icons.article_outlined),
          label: const Text('新建模板'),
        ),
        for (final template in templates.take(2))
          FilledButton.tonalIcon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LifeRecordEditorScreen(template: template),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(template.name),
          ),
      ],
    );
  }
}

class _TodayHabitsSection extends StatelessWidget {
  const _TodayHabitsSection({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final todaysHabits = habits
        .where(
          (habit) =>
              habit.status == HabitStatus.active &&
              _isExpectedDay(habit, today),
        )
        .toList();
    return _Section(
      title: '今日习惯',
      actionLabel: '全部',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LifeHabitsScreen()),
      ),
      child: todaysHabits.isEmpty
          ? const _SectionEmpty(
              icon: Icons.fact_check_outlined,
              text: '今天没有待打卡习惯',
            )
          : Column(
              children: [
                for (final habit in todaysHabits.take(5))
                  _TodayHabitTile(habit: habit),
              ],
            ),
    );
  }
}

class _TodayHabitTile extends ConsumerWidget {
  const _TodayHabitTile({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkInsAsync = ref.watch(lifeHabitCheckInsProvider(habit.id));
    final todayStatus = checkInsAsync.value == null
        ? null
        : _todayStatus(checkInsAsync.value!);
    final done =
        todayStatus == HabitCheckInStatus.completed ||
        todayStatus == HabitCheckInStatus.partial;
    final skipped = todayStatus == HabitCheckInStatus.skipped;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done
            ? Icons.check_circle
            : skipped
            ? Icons.remove_circle_outline
            : Icons.radio_button_unchecked,
      ),
      title: Text(habit.title),
      subtitle: Text(_habitSummary(habit, done, skipped)),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '跳过',
            onPressed: todayStatus == null
                ? () => _addCheckIn(
                    context,
                    ref,
                    HabitCheckIn(
                      habitId: habit.id,
                      status: HabitCheckInStatus.skipped,
                    ),
                    '${habit.title} 已跳过',
                  )
                : null,
            icon: const Icon(Icons.skip_next_outlined),
          ),
          IconButton.filledTonal(
            tooltip: '完成',
            onPressed: done
                ? null
                : () => _addCheckIn(
                    context,
                    ref,
                    HabitCheckIn(habitId: habit.id),
                    '${habit.title} 已打卡',
                  ),
            icon: const Icon(Icons.check),
          ),
        ],
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
}

class _RecentRecordsSection extends StatelessWidget {
  const _RecentRecordsSection({required this.records, required this.templates});

  final List<LifeRecord> records;
  final List<RecordTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final template in templates) template.id: template};
    final recent = [...records]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return _Section(
      title: '最近记录',
      actionLabel: '全部',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LifeRecordsScreen()),
      ),
      child: recent.isEmpty
          ? const _SectionEmpty(
              icon: Icons.receipt_long_outlined,
              text: '还没有日常记录',
            )
          : Column(
              children: [
                for (final record in recent.take(4))
                  _RecentRecordTile(
                    record: record,
                    template: byId[record.templateId],
                  ),
              ],
            ),
    );
  }
}

class _RecentRecordTile extends StatelessWidget {
  const _RecentRecordTile({required this.record, required this.template});

  final LifeRecord record;
  final RecordTemplate? template;

  @override
  Widget build(BuildContext context) {
    final date = record.occurredAt.toLocal().toString().split(' ').first;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(record.title),
      subtitle: Text('${template?.name ?? '记录'} · $date'),
      onTap: () {
        if (template == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeTemplateRecordsScreen(template: template!),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(message, maxLines: 2)),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _LifeSectionTile extends StatelessWidget {
  const _LifeSectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

DateTime _dayOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

HabitCheckInStatus? _todayStatus(List<HabitCheckIn> checkIns) {
  final today = _dayOnly(DateTime.now());
  for (final checkIn in checkIns) {
    if (_dayOnly(checkIn.checkedAt) == today) return checkIn.status;
  }
  return null;
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

String _habitSummary(Habit habit, bool done, bool skipped) {
  final status = done
      ? '已完成'
      : skipped
      ? '已跳过'
      : '待打卡';
  final target = habit.target == null
      ? ''
      : ' · ${_formatNumber(habit.target!.targetValue)} ${habit.target!.unit}';
  return '$status$target';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
