# Facilis Flash Storage Backup

Automated backup for mounted Facilis volumes using `fccmd` discovery + `rsync`, designed for manual runs or macOS LaunchAgent scheduling.

## What It Does

- Detects mounted Facilis volumes from `fccmd list_mounts`
- Backs up each mounted volume to a destination path
- Uses an rsync exclude list from `facilis_backup_exclude.txt`
- Prints readable status logs with:
  - host and start time
  - backup destination free space
  - per-volume source size and available space
  - per-volume files copied, copied size (GB), and duration
  - total duration

## Project Files

- `facilis_backup.sh`: backup script
- `facilis_backup_exclude.txt`: rsync exclude patterns
- `com.scn.facilis-backup.plist`: LaunchAgent config (label: `com.scn.facilis-backup`)
- `README.md`: documentation

## Requirements

- macOS
- `rsync`
- `fccmd` (Facilis CLI)
- Read access to `/Volumes/<facilis-volume>`
- Write access to backup destination

## Quick Start

Run from the `facilis_backup` folder.

```bash
./facilis_backup.sh
```

Default destination is:

```bash
/Volumes/blackhole/facilis_backup
```

Override destination for one run:

```bash
BACKUP_DEST="/path/to/destination" ./facilis_backup.sh
```

## Dry-Run Testing

Use dry-run before production runs:

```bash
DRY_RUN=1 ./facilis_backup.sh
```

Use a throwaway destination while testing:

```bash
mkdir -p /tmp/facilis_backups_test
DRY_RUN=1 BACKUP_DEST=/tmp/facilis_backups_test ./facilis_backup.sh
```

How this works:

- `DRY_RUN=1` makes the script add `rsync -n` (`--dry-run`)
- rsync reports what it would transfer, but does not write files
- `BACKUP_DEST=...` and `DRY_RUN=...` set before a command apply only to that single command
- No script file edits are required for testing

## Configuration

### Exclude Patterns

Edit `facilis_backup_exclude.txt`. Patterns are relative to each source volume root.

### Environment Variables

- `BACKUP_DEST`: backup destination path
- `DRY_RUN`: set to `1` for rsync dry-run mode
- `EMAIL_TO`: optional recipient for end-of-run log email
- `EMAIL_SUBJECT_PREFIX`: optional subject prefix (default: `Facilis backup report`)

## LaunchAgent Setup

Install:

```bash
cp com.scn.facilis-backup.plist ~/Library/LaunchAgents/
chmod 644 ~/Library/LaunchAgents/com.scn.facilis-backup.plist
launchctl load ~/Library/LaunchAgents/com.scn.facilis-backup.plist
```

Verify:

```bash
launchctl list | grep com.scn.facilis-backup
```

Unload:

```bash
launchctl unload ~/Library/LaunchAgents/com.scn.facilis-backup.plist
```

Schedule is set with `StartCalendarInterval` to run daily at `00:30`.

## Logging

- Script logs to stdout/stderr
- LaunchAgent writes logs to `/Users/oah/Library/Logs/com.scn.facilis-backup/facilis_backup.log`
- Log levels: `INFO`, `WARN`, `ERROR`

## Email Reports (Optional)

The script can email the per-run log after completion using native utilities:

- `mail` (preferred)
- `sendmail` (fallback)

Enable for one manual run:

```bash
EMAIL_TO="you@example.com" ./facilis_backup.sh
```

Enable in LaunchAgent by adding environment variables under `EnvironmentVariables` in `com.scn.facilis-backup.plist`:

```xml
<key>EnvironmentVariables</key>
<dict>
  <key>EMAIL_TO</key>
  <string>you@example.com</string>
  <key>EMAIL_SUBJECT_PREFIX</key>
  <string>Facilis backup nightly</string>
</dict>
```

Notes:

- If `EMAIL_TO` is empty, no email is sent.
- If neither `mail` nor `sendmail` is available, backup continues and a warning is logged.

## Troubleshooting

### No volumes found

- Check Facilis mounts:

```bash
fccmd list_mounts
```

- Ensure `fccmd` is available in PATH

### Permission errors

- Confirm destination is writable
- Confirm source volumes are readable

### See launchd related logs

```bash
log stream --predicate 'process == "facilis_backup.sh"' --level debug
```
