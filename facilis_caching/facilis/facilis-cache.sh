#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FCP_BIN="${FCP_BIN:-$SCRIPT_DIR/fcp}"
LOG_DIR="$HOME/Library/Logs/Shortcut"
LOCK_FILE="/tmp/com.scn.facilis-cache.lockfile"

mkdir -p "$LOG_DIR" 2>/dev/null || true

# flock is held on an open file descriptor, including by fcp if the shell dies.
# Never remove the lock file: another process could already have it open.
if [[ "${FACILIS_CACHE_LOCK_HELD:-}" != "1" ]]; then
    exec /usr/bin/perl -MFcntl=:DEFAULT,:flock -e '
        my ($path, $script, @args) = @ARGV;
        umask 0022;
        die "Refusing symlink lock file: $path\n" if -l $path;
        sysopen(my $lock, $path, O_RDONLY | O_CREAT | O_NOFOLLOW, 0644)
            or die "Cannot open lock file $path: $!\n";
        die "Not a regular lock file: $path\n" unless -f $lock;
        if (!flock($lock, LOCK_EX | LOCK_NB)) {
            if ($!{EWOULDBLOCK} || $!{EAGAIN}) {
                print "--- Skipping run: facilis-cache.sh is already running ---\n";
                exit 0;
            }
            die "Cannot lock $path: $!\n";
        }
        $^F = fileno($lock);
        fcntl($lock, F_SETFD, 0) or die "Cannot preserve lock: $!\n";
        $ENV{FACILIS_CACHE_LOCK_HELD} = 1;
        exec "/bin/bash", $script, @args or die "Cannot start cache script: $!\n";
    ' "$LOCK_FILE" "$0" "$@"
fi
unset FACILIS_CACHE_LOCK_HELD

if pgrep -x "fcp" >/dev/null 2>&1; then
    echo "--- Skipping run at $(date): 'fcp' process is already running ---"
    exit 0
fi

echo "--- Cache run started at $(date) (user: $(id -un), host: $(hostname), pid: $$) ---"

if [[ ! -f "$FCP_BIN" ]]; then
    echo "--- Error: fcp binary not found at '$FCP_BIN'. Aborting at $(date) ---"
    exit 1
fi

if [[ ! -x "$FCP_BIN" ]]; then
    chmod +x "$FCP_BIN" 2>/dev/null || true
fi

# Strip quarantine attribute if present so launchd is never blocked by Gatekeeper
xattr -d com.apple.quarantine "$FCP_BIN" 2>/dev/null || true

is_mounted() {
    local vol_path="$1"
    mount | grep -Fq "on ${vol_path} ("
}

normalize_volume_path() {
    local input="$1"
    if [[ "$input" == /Volumes/* ]]; then
        echo "${input%/}"
    else
        echo "/Volumes/${input%/}"
    fi
}

discover_edit_volumes() {
    local vol
    shopt -s nullglob
    for vol in /Volumes/*_edit; do
        if is_mounted "$vol"; then
            echo "$vol"
        fi
    done
    shopt -u nullglob
}

declare -a TARGET_VOLUMES=()

# 1. Explicit CLI arguments take priority (e.g. ./facilis-cache.sh higif2_edit)
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        TARGET_VOLUMES+=("$(normalize_volume_path "$arg")")
    done
# 2. Optional SOURCE_VOL environment variable override
elif [[ -n "${SOURCE_VOL:-}" ]]; then
    TARGET_VOLUMES+=("$(normalize_volume_path "$SOURCE_VOL")")
# 3. Default: auto-detect all mounted /Volumes/*_edit volumes
else
    while IFS= read -r vol; do
        [[ -n "$vol" ]] && TARGET_VOLUMES+=("$vol")
    done < <(discover_edit_volumes)
fi

if [[ ${#TARGET_VOLUMES[@]} -eq 0 ]]; then
    echo "--- Error: No mounted '*_edit' volumes found in /Volumes. Aborting at $(date) ---"
    exit 1
fi

overall_status=0

for vol in "${TARGET_VOLUMES[@]}"; do
    if ! is_mounted "$vol"; then
        echo "--- Error: Volume '$vol' is not mounted. Skipping. ---"
        overall_status=1
        continue
    fi

    media_dir="$vol/Avid MediaFiles"
    if [[ ! -d "$media_dir" ]]; then
        echo "--- Warning: '$media_dir' not found on '$vol'. Skipping. ---"
        continue
    fi

    echo "--- Running fcp on '$media_dir' ---"
    if "$FCP_BIN" -q "$media_dir" -r; then
        echo "--- Completed '$media_dir' at $(date) ---"
    else
        rc=$?
        echo "--- Error: fcp exited with code $rc for '$media_dir' at $(date) ---"
        overall_status=$rc
    fi
done

echo "--- Cache run finished at $(date) (exit: $overall_status) ---"
exit "$overall_status"
