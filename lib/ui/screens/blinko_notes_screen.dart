import 'package:flutter/material.dart';
import 'package:flutterclaw/services/blinko_api_service.dart';
import 'package:flutterclaw/services/secure_key_store.dart';
import 'package:flutterclaw/ui/screens/blinko_note_detail_screen.dart';
import 'package:flutterclaw/ui/screens/auth/blinko_login_page.dart';

class BlinkoNotesScreen extends StatefulWidget {
  const BlinkoNotesScreen({super.key});

  @override
  State<BlinkoNotesScreen> createState() => _BlinkoNotesScreenState();
}

class _BlinkoNotesScreenState extends State<BlinkoNotesScreen> {
  final _searchCtl = TextEditingController();

  static const _pageSize = 30;

  BlinkoApiService? _api;
  List<BlinkoNote> _notes = [];
  bool _initializing = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final ready = await _loadCredentialsOrLogin();
    if (!mounted) return;
    setState(() => _initializing = false);
    if (ready) await _loadFirstPage();
  }

  Future<bool> _loadCredentialsOrLogin() async {
    final token = await SecureKeyStore.getApiKey('blinko');
    final baseUrl = await SecureKeyStore.getSecret('blinko_base_url');
    if (token != null &&
        token.isNotEmpty &&
        baseUrl != null &&
        baseUrl.isNotEmpty) {
      _api = BlinkoApiService(baseUrl: baseUrl, token: token);
      return true;
    }

    if (!mounted) return false;
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const BlinkoLoginPage()));
    if (loggedIn != true) return false;

    final newToken = await SecureKeyStore.getApiKey('blinko');
    final newBaseUrl = await SecureKeyStore.getSecret('blinko_base_url');
    if (newToken == null ||
        newToken.isEmpty ||
        newBaseUrl == null ||
        newBaseUrl.isEmpty) {
      return false;
    }
    _api = BlinkoApiService(baseUrl: newBaseUrl, token: newToken);
    return true;
  }

  Future<void> _loadFirstPage() async {
    if (_api == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });

    try {
      final notes = await _api!.listNotes(
        BlinkoNoteListQuery(
          page: 1,
          size: _pageSize,
          searchText: _searchCtl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _hasMore = notes.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_api == null || _loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    final nextPage = _page + 1;
    try {
      final notes = await _api!.listNotes(
        BlinkoNoteListQuery(
          page: nextPage,
          size: _pageSize,
          searchText: _searchCtl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _notes = [..._notes, ...notes];
        _hasMore = notes.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载更多失败：$e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _logout() async {
    await SecureKeyStore.deleteApiKey('blinko');
    await SecureKeyStore.deleteSecret('blinko_base_url');
    if (!mounted) return;
    setState(() {
      _api = null;
      _notes = [];
      _error = null;
    });
    await _bootstrap();
  }

  Future<void> _openCreateNote() async {
    final api = _api;
    if (api == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BlinkoNoteDetailScreen(api: api)),
    );
    if (changed == true) {
      await _loadFirstPage();
    }
  }

  Future<void> _openNote(BlinkoNote note) async {
    final api = _api;
    if (api == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlinkoNoteDetailScreen(
          api: api,
          noteId: note.id,
          initialNote: note,
        ),
      ),
    );
    if (changed == true) {
      await _loadFirstPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blinko 笔记'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _loadFirstPage,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建笔记',
        onPressed: _api == null ? null : _openCreateNote,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchCtl,
              hintText: '搜索笔记',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchCtl.text.isNotEmpty)
                  IconButton(
                    tooltip: '清空',
                    onPressed: () {
                      _searchCtl.clear();
                      _loadFirstPage();
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _loadFirstPage(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _notes.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _loadFirstPage);
    }

    if (_notes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('暂无笔记')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 480) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _notes.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == _notes.length) {
              return _ListFooter(
                loading: _loadingMore,
                hasMore: _hasMore,
                onLoadMore: _loadMore,
              );
            }
            return _NoteCard(
              note: _notes[index],
              onTap: () => _openNote(_notes[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final BlinkoNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _titleFromContent(note.content);
    final body = _bodyFromContent(note.content);
    final meta = _formatDate(note.updatedAt ?? note.createdAt);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? '未命名笔记' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.isTop)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.push_pin, size: 18),
                    ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaChip(icon: Icons.schedule, label: meta),
                  if (note.attachmentCount > 0)
                    _MetaChip(
                      icon: Icons.attach_file,
                      label: '${note.attachmentCount}',
                    ),
                  if (note.commentCount > 0)
                    _MetaChip(
                      icon: Icons.chat_bubble_outline,
                      label: '${note.commentCount}',
                    ),
                  for (final tag in note.tags.take(4))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(tag),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleFromContent(String content) {
    final clean = _cleanContent(content);
    if (clean.isEmpty) return '';
    final firstLine = clean.split('\n').first.trim();
    return firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
  }

  static String _bodyFromContent(String content) {
    final clean = _cleanContent(content);
    if (clean.isEmpty) return '';
    final lines = clean.split('\n');
    if (lines.length <= 1) return '';
    return lines.skip(1).join('\n').trim();
  }

  static String _cleanContent(String content) {
    return content
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .trim();
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '未知时间';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
  });

  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('没有更多了')),
      );
    }
    return TextButton.icon(
      onPressed: onLoadMore,
      icon: const Icon(Icons.expand_more),
      label: const Text('加载更多'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
