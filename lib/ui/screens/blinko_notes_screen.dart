import 'package:flutter/material.dart';
import 'package:flutterclaw/services/secure_key_store.dart';
import 'package:flutterclaw/ui/screens/auth/blinko_login_page.dart';

class BlinkoNotesScreen extends StatefulWidget {
  const BlinkoNotesScreen({super.key});

  @override
  State<BlinkoNotesScreen> createState() => _BlinkoNotesScreenState();
}

class _BlinkoNotesScreenState extends State<BlinkoNotesScreen> {
  bool _checkingLogin = true;

  @override
  void initState() {
    super.initState();
    _ensureLoggedIn();
  }

  Future<void> _ensureLoggedIn() async {
    final token = await SecureKeyStore.getApiKey('blinko');
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BlinkoLoginPage(
            onLoginSuccess: () {
              Navigator.of(context).pop();
              if (mounted) setState(() => _checkingLogin = false);
            },
          ),
        ),
      );
      return;
    }

    setState(() => _checkingLogin = false);
  }

  Future<void> _logout() async {
    await SecureKeyStore.deleteApiKey('blinko');
    await SecureKeyStore.deleteSecret('blinko_base_url');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BlinkoLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _demoNotes;

    if (_checkingLogin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记列表'),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('退出'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final note = notes[index];
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoteItem {
  final String title;
  final String content;

  const _NoteItem({required this.title, required this.content});
}

const _demoNotes = <_NoteItem>[
  _NoteItem(
    title: '欢迎使用 Blinko',
    content:
        '这是一个示例笔记列表页面。你可以把这里替换成真实接口返回的数据。为了保证界面整洁，长内容会自动截断并显示省略号。',
  ),
  _NoteItem(
    title: '待办事项',
    content: '1. 对接后端笔记列表接口。2. 下拉刷新。3. 点击卡片进入详情。4. 支持搜索与标签筛选。',
  ),
  _NoteItem(
    title: '会议记录',
    content:
        '今天讨论了登录流程、Token 存储、Base URL 配置等功能。下一步将接入实际的笔记数据源，并补充错误态和空态展示。',
  ),
];
