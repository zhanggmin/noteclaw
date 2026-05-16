import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterclaw/core/app_providers.dart';
import 'package:flutterclaw/services/backup_service.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  String? _status;
  BackupExportResult? _lastExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Export or restore your FlutterClaw data.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Backups include config, agents, memory, sessions, and life management data. API keys, secrets, WhatsApp login state, and browser profiles are excluded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined),
            label: const Text('Export Backup'),
            onPressed: _busy ? null : _exportBackup,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import Backup'),
            onPressed: _busy ? null : _importBackup,
          ),
          if (_lastExport != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Share Last Export'),
              onPressed: _busy ? null : () => _shareBackup(_lastExport!),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Save Last Export'),
              onPressed: _busy ? null : () => _saveBackup(_lastExport!),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 24),
            Text(_status!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _status = 'Creating backup...';
    });

    try {
      final result = await ref.read(backupServiceProvider).exportBackup();
      if (!mounted) return;
      setState(() {
        _lastExport = result;
        _status =
            'Created ${result.fileName} with ${result.includedFiles} files.';
      });
      await _showExportActions(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showExportActions(BackupExportResult result) async {
    final action = await showModalBottomSheet<_ExportAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Share backup'),
              onTap: () => Navigator.pop(context, _ExportAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Save to file'),
              onTap: () => Navigator.pop(context, _ExportAction.save),
            ),
          ],
        ),
      ),
    );

    if (action == _ExportAction.share) {
      await _shareBackup(result);
    } else if (action == _ExportAction.save) {
      await _saveBackup(result);
    }
  }

  Future<void> _shareBackup(BackupExportResult result) async {
    await Share.shareXFiles(
      [XFile(result.file.path, mimeType: 'application/zip')],
      subject: 'FlutterClaw backup',
      text: 'FlutterClaw backup: ${result.fileName}',
    );
  }

  Future<void> _saveBackup(BackupExportResult result) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save FlutterClaw backup',
        fileName: result.fileName,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: result.bytes,
      );
      if (!mounted) return;
      setState(() {
        _status = savedPath == null
            ? 'Backup created but save was cancelled.'
            : 'Backup saved to $savedPath';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Save is unavailable here. Use Share instead.');
    }
  }

  Future<void> _importBackup() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = pick?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'This will overwrite your normal FlutterClaw data after creating a local rollback backup. API keys and secrets are not restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _status = 'Importing backup...';
    });

    try {
      final result = await ref
          .read(backupServiceProvider)
          .importBackup(File(path));
      ref.invalidate(configManagerProvider);
      if (!mounted) return;
      setState(() {
        _status =
            'Import complete. Restored ${result.restoredFiles} files. Re-enter API keys in Credentials before using providers.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

enum _ExportAction { share, save }
