import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_record_editor_screen.dart';

class LifeTemplateRecordsScreen extends ConsumerWidget {
  const LifeTemplateRecordsScreen({super.key, required this.template});

  final RecordTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(lifeRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(template.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeRecordEditorScreen(template: template),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('新建记录'),
      ),
      body: recordsAsync.when(
        data: (records) {
          final templateRecords = records
              .where((record) => record.templateId == template.id)
              .toList();
          if (templateRecords.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _RecordStats(records: []),
                SizedBox(height: 16),
                _EmptyLifeState(
                  icon: Icons.receipt_long_outlined,
                  title: '还没有记录',
                  subtitle: '点击右下角新建该模板下的记录。',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RecordStats(records: templateRecords),
              const SizedBox(height: 16),
              for (final record in templateRecords) ...[
                _TemplateRecordTile(record: record, template: template),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '加载记录失败：$error',
          onRetry: () => ref.invalidate(lifeRecordsProvider),
        ),
      ),
    );
  }
}

class _TemplateRecordTile extends ConsumerWidget {
  const _TemplateRecordTile({required this.record, required this.template});

  final LifeRecord record;
  final RecordTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = record.occurredAt.toLocal().toString().split(' ').first;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(record.title),
        subtitle: Text(_subtitle(date)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeRecordEditorScreen(record: record),
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) async {
            final confirmed = await _confirmAction(
              context,
              value,
              record.title,
            );
            if (!confirmed) return;
            final repository = await ref.read(
              lifeManagementRepositoryProvider.future,
            );
            if (value == 'delete') {
              await repository.deleteRecord(record.id);
            } else {
              await repository.archiveRecord(record.id);
            }
            ref.invalidate(lifeRecordsProvider);
            if (!context.mounted) return;
            final action = value == 'delete' ? '删除' : '归档';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${record.title} 已$action')));
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'archive', child: Text('归档')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }

  String _subtitle(String date) {
    final values = <String>[date];
    for (final field in template.fields.take(3)) {
      final value = record.fields[field.key];
      if (value == null || '$value'.isEmpty) continue;
      values.add('${field.label}: $value');
    }
    if (record.note != null && record.note!.isNotEmpty) {
      values.add(record.note!);
    }
    return values.join(' · ');
  }

  Future<bool> _confirmAction(
    BuildContext context,
    String action,
    String title,
  ) async {
    final isDelete = action == 'delete';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDelete ? '删除记录' : '归档记录'),
        content: Text(
          isDelete
              ? '确定删除“$title”？删除后不会在默认列表中显示。'
              : '确定归档“$title”？归档后不会在默认列表中显示。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDelete ? '删除' : '归档'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _RecordStats extends StatelessWidget {
  const _RecordStats({required this.records});

  final List<LifeRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last7 = _countSince(now.subtract(const Duration(days: 7)));
    final last30 = _countSince(now.subtract(const Duration(days: 30)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCell(label: '总记录', value: records.length),
                ),
                Expanded(
                  child: _StatCell(label: '30 天', value: last30),
                ),
                Expanded(
                  child: _StatCell(label: '7 天', value: last7),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('近 35 天', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _Heatmap(records: records),
          ],
        ),
      ),
    );
  }

  int _countSince(DateTime start) {
    return records.where((record) => !record.occurredAt.isBefore(start)).length;
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.records});

  final List<LifeRecord> records;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final counts = <DateTime, int>{};
    for (final record in records) {
      final day = _dateOnly(record.occurredAt);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final days = [
      for (var i = 34; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final count = counts[day] ?? 0;
        return Tooltip(
          message:
              '${day.year}-${_twoDigits(day.month)}-${_twoDigits(day.day)}：$count 次',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _colorForCount(context, count),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Color _colorForCount(BuildContext context, int count) {
    final colors = Theme.of(context).colorScheme;
    if (count <= 0) return colors.surfaceContainerHighest;
    if (count == 1) return colors.primaryContainer;
    if (count == 2) return colors.primary.withValues(alpha: 0.65);
    return colors.primary;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
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
