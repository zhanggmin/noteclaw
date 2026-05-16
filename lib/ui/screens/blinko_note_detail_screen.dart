import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutterclaw/services/blinko_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BlinkoNoteDetailScreen extends StatefulWidget {
  const BlinkoNoteDetailScreen({
    super.key,
    required this.api,
    this.noteId,
    this.initialNote,
  });

  final BlinkoApiService api;
  final int? noteId;
  final BlinkoNote? initialNote;

  @override
  State<BlinkoNoteDetailScreen> createState() => _BlinkoNoteDetailScreenState();
}

class _BlinkoNoteDetailScreenState extends State<BlinkoNoteDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentCtl = TextEditingController();

  BlinkoNote? _note;
  bool _loading = false;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  bool get _isCreate => widget.noteId == null;

  Future<void> _copyContent() async {
    final content = _contentCtl.text.trim();
    if (content.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('笔记内容已复制'), duration: Duration(seconds: 1)),
    );
  }

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _contentCtl.text = widget.initialNote?.content ?? '';
    _editing = _isCreate;
    if (!_isCreate) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _contentCtl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final id = widget.noteId;
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final note = await widget.api.noteDetail(id);
      if (!mounted) return;
      setState(() {
        _note = note;
        if (note != null) _contentCtl.text = note.content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.upsertNote(
        BlinkoNoteUpsertRequest(
          id: widget.noteId,
          content: _contentCtl.text.trim(),
          type: _note?.type ?? -1,
          isArchived: _note?.isArchived,
          isTop: _note?.isTop,
          isRecycle: _note?.isRecycle,
        ),
      );
      if (!mounted) return;
      if (_isCreate) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _editing = false);
        await _loadDetail();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _trash() async {
    final id = widget.noteId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移到回收站'),
        content: const Text('确定要将这条笔记移到回收站吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移到回收站'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.trashNotes([id]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreate ? '新建笔记' : '笔记详情';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isCreate)
            IconButton(
              tooltip: '刷新',
              onPressed: _loading || _saving ? null : _loadDetail,
              icon: const Icon(Icons.refresh),
            ),
          if (!_isCreate)
            IconButton(
              tooltip: '复制内容',
              onPressed: _saving || _contentCtl.text.trim().isEmpty
                  ? null
                  : _copyContent,
              icon: const Icon(Icons.copy_outlined),
            ),
          if (!_isCreate)
            IconButton(
              tooltip: _editing ? '预览' : '编辑',
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit),
            ),
          if (!_isCreate)
            IconButton(
              tooltip: '移到回收站',
              onPressed: _saving ? null : _trash,
              icon: const Icon(Icons.delete_outline),
            ),
          if (_editing)
            IconButton(
              tooltip: '保存',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading && _note == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_editing)
                      TextFormField(
                        controller: _contentCtl,
                        minLines: 12,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: '内容',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return '请输入笔记内容';
                          }
                          return null;
                        },
                      )
                    else
                      _MarkdownPreview(content: _contentCtl.text),
                    if (_note != null) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetaChip(label: 'ID ${_note!.id}'),
                          _MetaChip(label: '类型 ${_note!.type}'),
                          if (_note!.isTop) const _MetaChip(label: '置顶'),
                          if (_note!.isArchived) const _MetaChip(label: '已归档'),
                          if (_note!.attachmentCount > 0)
                            _MetaChip(label: '附件 ${_note!.attachmentCount}'),
                          if (_note!.commentCount > 0)
                            _MetaChip(label: '评论 ${_note!.commentCount}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final markdown = content.trim();

    if (markdown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Text(
            '暂无内容',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SelectionArea(
      child: MarkdownBody(
        data: markdown,
        selectable: false,
        onTapLink: (text, href, title) {
          if (href == null) return;
          final uri = Uri.tryParse(href);
          if (uri != null) launchUrl(uri);
        },
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          h1: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          h2: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          h3: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          blockquote: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
          blockquoteDecoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(left: BorderSide(color: colors.primary, width: 4)),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          code: TextStyle(
            fontFamily: 'monospace',
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
          ),
          codeblockDecoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          codeblockPadding: const EdgeInsets.all(12),
          a: TextStyle(
            color: colors.primary,
            decoration: TextDecoration.underline,
          ),
          tableBorder: TableBorder.all(color: colors.outlineVariant),
          tableHead: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
          tableBody: TextStyle(color: colors.onSurface),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}
