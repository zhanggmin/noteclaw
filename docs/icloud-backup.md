# iCloud Backup

FlutterClaw uses the existing backup archive format for iCloud backups. The
Dart layer still creates the same sanitized `.zip` backup, and iOS only copies
that archive into the app's iCloud Drive documents container.

## User Flow

1. Open **Settings > Backup & Restore**.
2. Tap **Export Backup**.
3. On iOS, choose **Save to iCloud Drive** from the export actions.
4. The app writes the generated backup zip to:

   ```text
   iCloud Drive/FlutterClaw/Backups/
   ```

The exported file name follows the existing pattern:

```text
flutterclaw-backup-YYYYMMDD-HHMMSS.zip
```

## Restore From iCloud

There is no dedicated iCloud backup browser yet. Restore uses the existing
backup import flow:

1. Open **Settings > Backup & Restore**.
2. Tap **Import Backup**.
3. In the system file picker, browse to iCloud Drive and select a
   `flutterclaw-backup-*.zip` file.
4. Confirm the import.

The import path is the same as local restore. The app validates the manifest,
creates a local rollback backup, restores allowed FlutterClaw data entries, and
reloads config.

## Backup Contents

Included:

- `config.json`, with sensitive values redacted
- `auth_profiles.json`
- `workspace`
- `agents`
- `life_management`

Excluded:

- API keys, tokens, passwords, and secrets
- Secure storage contents
- WhatsApp login state
- Browser profiles
- Temporary files and rollback backups

After restore, users must re-enter credentials and API keys.

## Apple ID and iCloud Requirements

The app does not implement Apple ID sign-in. iCloud Drive access is provided by
iOS through the current device account.

For iCloud backup to work on a device:

- The user must be signed in to an Apple ID in iOS Settings.
- iCloud Drive must be enabled for the Apple ID.
- FlutterClaw must be allowed to use iCloud Drive.
- The app must be signed with provisioning profiles that include the iCloud
  Documents entitlement.

If any of these are missing, `FileManager.url(forUbiquityContainerIdentifier:)`
returns `nil`, and the app reports that iCloud Drive is unavailable.

## Implementation

### Dart

`BackupService.exportBackup()` creates the backup zip in the temporary
`flutterclaw_backups` directory. `BackupService.saveBackupToICloud()` then calls
the native iOS bridge:

```text
MethodChannel: ai.flutterclaw/icloud_backup
Method: saveBackup
Arguments:
  sourcePath: local temporary zip path
  fileName: generated backup file name
```

The Backup & Restore screen shows the iCloud action only on iOS.

### iOS

`AppDelegate.setupICloudBackupChannel()` registers the method channel. The
native `saveBackupToICloud` handler:

1. Resolves the app iCloud ubiquity container with
   `FileManager.url(forUbiquityContainerIdentifier: nil)`.
2. Creates `Documents/Backups` inside the container.
3. Copies the temporary backup zip to that folder.
4. Returns the destination path to Dart.

The configured iCloud container is:

```text
iCloud.chinafix.mobile.detection
```

The container is declared in:

- `ios/Runner/Runner.entitlements`
- `ios/Runner/RunnerDebug.entitlements`
- `ios/Runner/RunnerRelease.entitlements`
- `ios/Runner/Info.plist`

## Current Limitations

- iCloud restore is file-picker based; there is no in-app list of available
  iCloud backups.
- Backup is manual; there is no scheduled automatic iCloud backup.
- iCloud availability can only be verified on a signed iOS device or simulator
  configured with iCloud.
