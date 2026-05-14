import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/features/life_management/life_management.dart';
import 'package:flutterclaw/features/life_management/life_management_providers.dart';
import 'package:flutterclaw/features/life_management/presentation/life_record_editor_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_record_template_editor_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_template_records_screen.dart';

class LifeRecordsScreen extends ConsumerStatefulWidget {
  const LifeRecordsScreen({super.key});

  @override
  ConsumerState<LifeRecordsScreen> createState() => _LifeRecordsScreenState();
}

class _LifeRecordsScreenState extends ConsumerState<LifeRecordsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(lifeRecordsProvider);
    final templatesAsync = ref.watch(lifeRecordTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('记录模板')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LifeRecordTemplateEditorScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('新建模板'),
      ),
      body: templatesAsync.when(
        data: (templates) => recordsAsync.when(
          data: (records) => _buildTemplates(context, templates, records),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: '加载记录失败：$error',
            onRetry: () => ref.invalidate(lifeRecordsProvider),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '加载模板失败：$error',
          onRetry: () => ref.invalidate(lifeRecordTemplatesProvider),
        ),
      ),
    );
  }

  Widget _buildTemplates(
    BuildContext context,
    List<RecordTemplate> templates,
    List<LifeRecord> records,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredTemplates = templates.where((template) {
      if (query.isEmpty) return true;
      final text = [
        template.name,
        template.description ?? '',
        template.fields.map((field) => field.label).join(' '),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: '搜索模板',
            hintText: '模板名称、说明或字段',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (templates.isEmpty)
          const _EmptyLifeState(
            icon: Icons.article_outlined,
            title: '还没有模板',
            subtitle: '点击右下角新建模板，再添加该模板下的记录。',
          )
        else if (filteredTemplates.isEmpty)
          const _EmptyLifeState(
            icon: Icons.search_off_outlined,
            title: '没有匹配模板',
            subtitle: '换个关键词试试。',
          )
        else
          for (final template in filteredTemplates) ...[
            _TemplateSummaryCard(
              template: template,
              records: records
                  .where((record) => record.templateId == template.id)
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TemplateSummaryCard extends StatelessWidget {
  const _TemplateSummaryCard({required this.template, required this.records});

  final RecordTemplate template;
  final List<LifeRecord> records;

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final latest = sorted.isEmpty ? null : sorted.first.occurredAt;
    final latestText = latest == null
        ? '暂无记录'
        : '最近 ${latest.toLocal().toString().split(' ').first}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.article_outlined),
        title: Text(template.name),
        subtitle: Text('$latestText · ${records.length} 次记录'),
        trailing: FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LifeRecordEditorScreen(template: template),
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('记录'),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeTemplateRecordsScreen(template: template),
          ),
        ),
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LifeRecordTemplateEditorScreen(template: template),
          ),
        ),
      ),
    );
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
