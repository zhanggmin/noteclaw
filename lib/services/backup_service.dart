library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutterclaw/data/models/config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupExportResult {
  const BackupExportResult({
    required this.file,
    required this.fileName,
    required this.bytes,
    required this.includedFiles,
  });

  final File file;
  final String fileName;
  final Uint8List bytes;
  final int includedFiles;
}

class BackupValidationResult {
  const BackupValidationResult({
    required this.manifest,
    required this.fileCount,
  });

  final Map<String, dynamic> manifest;
  final int fileCount;
}

class BackupImportResult {
  const BackupImportResult({
    required this.restoredFiles,
    required this.rollbackFile,
  });

  final int restoredFiles;
  final File rollbackFile;
}

class BackupService {
  BackupService({required this.configManager});

  final ConfigManager configManager;

  static const MethodChannel _icloudChannel = MethodChannel(
    'ai.flutterclaw/icloud_backup',
  );

  static const int backupFormatVersion = 1;
  static const String manifestPath = 'manifest.json';

  static const List<String> _includedTopLevelEntries = [
    'config.json',
    'auth_profiles.json',
    'workspace',
    'agents',
    'life_management',
  ];

  static const List<String> _excludedRelativePrefixes = [
    'browser_profiles',
    'backups',
  ];

  Future<BackupExportResult> exportBackup({String? filePrefix}) async {
    final configDir = await configManager.configDir;
    final configDirectory = Directory(configDir);
    final packageInfo = await PackageInfo.fromPlatform();
    final now = DateTime.now().toUtc();
    final stamp = _timestampForFile(now);
    final fileName = '${filePrefix ?? 'flutterclaw-backup'}-$stamp.zip';

    final archive = Archive();
    var includedFiles = 0;

    if (await configDirectory.exists()) {
      for (final entry in _includedTopLevelEntries) {
        final entityPath = p.join(configDir, entry);
        final entityType = await FileSystemEntity.type(entityPath);
        if (entityType == FileSystemEntityType.notFound) continue;

        if (entityType == FileSystemEntityType.directory) {
          includedFiles += await _addDirectory(
            archive,
            Directory(entityPath),
            archivePrefix: 'flutterclaw/$entry',
            rootPath: entityPath,
          );
        } else if (entityType == FileSystemEntityType.file) {
          final bytes = entry == 'config.json'
              ? await _sanitizedConfigBytes(File(entityPath))
              : await File(entityPath).readAsBytes();
          archive.addFile(ArchiveFile.bytes('flutterclaw/$entry', bytes));
          includedFiles++;
        }
      }
    }

    archive.addFile(
      ArchiveFile.string(
        manifestPath,
        const JsonEncoder.withIndent('  ').convert({
          'format': 'flutterclaw_backup',
          'format_version': backupFormatVersion,
          'created_at': now.toIso8601String(),
          'app': {
            'name': packageInfo.appName,
            'package_name': packageInfo.packageName,
            'version': packageInfo.version,
            'build_number': packageInfo.buildNumber,
          },
          'included': [
            'flutterclaw/config.json',
            'flutterclaw/auth_profiles.json',
            'flutterclaw/workspace',
            'flutterclaw/agents',
            'flutterclaw/life_management',
          ],
          'excluded': [
            'secure_storage',
            'whatsapp-auth',
            'flutterclaw/browser_profiles',
            'temporary_files',
            'backup_rollback_files',
          ],
          'notes': [
            'API keys, tokens, passwords, and secrets are redacted.',
            'Credentials must be re-entered after restore.',
          ],
        }),
      ),
    );

    final encoded = ZipEncoder().encode(archive);
    final bytes = Uint8List.fromList(encoded);
    final backupDir = await _backupTempDir();
    final file = File(p.join(backupDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    return BackupExportResult(
      file: file,
      fileName: fileName,
      bytes: bytes,
      includedFiles: includedFiles,
    );
  }

  Future<String> saveBackupToICloud(BackupExportResult backup) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('iCloud backup is only available on iOS.');
    }

    final path = await _icloudChannel.invokeMethod<String>('saveBackup', {
      'sourcePath': backup.file.path,
      'fileName': backup.fileName,
    });
    if (path == null || path.isEmpty) {
      throw StateError('iCloud backup did not return a saved path.');
    }
    return path;
  }

  Future<BackupValidationResult> validateBackup(File file) async {
    final archive = await _decodeArchive(file);
    final manifestFile = archive.findFile(manifestPath);
    if (manifestFile == null || !manifestFile.isFile) {
      throw FormatException('Backup is missing $manifestPath.');
    }

    final manifest =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    if (manifest['format'] != 'flutterclaw_backup') {
      throw const FormatException('This is not a FlutterClaw backup.');
    }
    final version = manifest['format_version'];
    if (version is! int || version > backupFormatVersion) {
      throw FormatException('Unsupported backup format version: $version.');
    }

    final hasData = archive.files.any(
      (file) => file.isFile && file.name.startsWith('flutterclaw/'),
    );
    if (!hasData) {
      throw const FormatException('Backup does not contain FlutterClaw data.');
    }

    _validateArchivePaths(archive);
    return BackupValidationResult(
      manifest: manifest,
      fileCount: archive.files.where((file) => file.isFile).length,
    );
  }

  Future<BackupImportResult> importBackup(File file) async {
    await validateBackup(file);
    final archive = await _decodeArchive(file);
    final staging = await _freshTempDir('restore-staging');

    try {
      final restoredFiles = await _extractFlutterClawData(archive, staging);
      if (restoredFiles == 0) {
        throw const FormatException('Backup contains no restorable files.');
      }

      final rollback = await exportBackup(filePrefix: 'flutterclaw-rollback');
      try {
        await _restoreAllowedEntries(
          Directory(p.join(staging.path, 'flutterclaw')),
        );
      } catch (error) {
        await _restoreFromBackupFile(rollback.file);
        throw StateError(
          'Import failed and previous data was restored: $error',
        );
      }
      await configManager.load();

      return BackupImportResult(
        restoredFiles: restoredFiles,
        rollbackFile: rollback.file,
      );
    } catch (_) {
      rethrow;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<int> _addDirectory(
    Archive archive,
    Directory directory, {
    required String archivePrefix,
    required String rootPath,
  }) async {
    var count = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;

      final relative = p.relative(entity.path, from: rootPath);
      final normalizedRelative = _toArchivePath(relative);
      if (_isExcludedRelativePath(p.join(p.basename(rootPath), relative))) {
        continue;
      }

      final bytes = await entity.readAsBytes();
      archive.addFile(
        ArchiveFile.bytes('$archivePrefix/$normalizedRelative', bytes),
      );
      count++;
    }
    return count;
  }

  Future<Uint8List> _sanitizedConfigBytes(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw);
    final sanitized = _redactSensitiveJson(json);
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(sanitized)),
    );
  }

  Object? _redactSensitiveJson(Object? value) {
    if (value is List) {
      return value.map(_redactSensitiveJson).toList();
    }
    if (value is Map) {
      return value.map((key, child) {
        final stringKey = key.toString();
        if (_isSensitiveKey(stringKey)) {
          return MapEntry(key, '');
        }
        return MapEntry(key, _redactSensitiveJson(child));
      });
    }
    return value;
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized == 'api_key' ||
        normalized == 'apikey' ||
        normalized == 'password' ||
        normalized == 'client_secret' ||
        normalized == 'aws_secret_key' ||
        normalized.endsWith('_token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('token');
  }

  bool _isExcludedRelativePath(String relativePath) {
    final normalized = _toArchivePath(relativePath);
    return _excludedRelativePrefixes.any(
      (prefix) => normalized == prefix || normalized.startsWith('$prefix/'),
    );
  }

  Future<Archive> _decodeArchive(File file) async {
    try {
      return ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (error) {
      throw FormatException('Unable to read backup zip: $error');
    }
  }

  void _validateArchivePaths(Archive archive) {
    for (final entry in archive.files) {
      final normalized = p.posix.normalize(entry.name);
      if (p.posix.isAbsolute(entry.name) ||
          normalized == '..' ||
          normalized.startsWith('../') ||
          normalized.contains('/../')) {
        throw FormatException('Backup contains an unsafe path: ${entry.name}');
      }
    }
  }

  Future<int> _extractFlutterClawData(
    Archive archive,
    Directory staging,
  ) async {
    var count = 0;
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('flutterclaw/')) continue;
      final normalized = p.posix.normalize(entry.name);
      final segments = p.posix.split(normalized);
      if (segments.length < 2 || segments.first != 'flutterclaw') continue;

      final outputPath = p.joinAll([staging.path, ...segments]);
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(entry.content as List<int>, flush: true);
      count++;
    }
    return count;
  }

  Future<void> _restoreAllowedEntries(Directory stagedFlutterClaw) async {
    if (!await stagedFlutterClaw.exists()) {
      throw const FormatException('Backup staging data is missing.');
    }

    final configDir = await configManager.configDir;
    await Directory(configDir).create(recursive: true);

    for (final entry in _includedTopLevelEntries) {
      final source = p.join(stagedFlutterClaw.path, entry);
      final target = p.join(configDir, entry);
      final sourceType = await FileSystemEntity.type(source);
      final targetType = await FileSystemEntity.type(target);

      if (targetType != FileSystemEntityType.notFound) {
        if (targetType == FileSystemEntityType.directory) {
          await Directory(target).delete(recursive: true);
        } else {
          await File(target).delete();
        }
      }

      if (sourceType == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(source), Directory(target));
      } else if (sourceType == FileSystemEntityType.file) {
        await File(target).parent.create(recursive: true);
        await File(source).copy(target);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  Future<void> _restoreFromBackupFile(File file) async {
    final archive = await _decodeArchive(file);
    final staging = await _freshTempDir('rollback-staging');
    try {
      await _extractFlutterClawData(archive, staging);
      await _restoreAllowedEntries(
        Directory(p.join(staging.path, 'flutterclaw')),
      );
      await configManager.load();
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<Directory> _backupTempDir() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'flutterclaw_backups'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _freshTempDir(String name) async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        temp.path,
        'flutterclaw_backup_${name}_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    return dir;
  }

  String _timestampForFile(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  String _toArchivePath(String path) => p.split(path).join('/');
}
