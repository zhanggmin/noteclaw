import 'package:flutter/material.dart';
import 'package:flutterclaw/features/life_management/presentation/life_habits_screen.dart';
import 'package:flutterclaw/features/life_management/presentation/life_records_screen.dart';

class LifeHomeScreen extends StatelessWidget {
  const LifeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            '记录日常事件，养成习惯，并在后续阶段接入目标和计划。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
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
