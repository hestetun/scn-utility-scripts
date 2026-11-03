#!/bin/bash
set -euo pipefail

LABEL="com.scn.facilis-cache"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/facilis"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LOG_DIR="$HOME/Library/Logs/Shortcut"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$LABEL.plist"
GUI_DOMAIN="gui/$(id -u)"

ACTION="install"
IN_PLACE=0
PURGE=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Rolls out and manages the Facilis media cache LaunchAgent ($LABEL)
for the currently logged-in user ($(id -un)).
Scheduled daily at 20:00 and 03:00.

Options:
  --status            Show LaunchAgent status, paths, and detected *_edit volumes
  --uninstall         Unload and remove the LaunchAgent plist
  --purge             With --uninstall, also remove $DEFAULT_INSTALL_DIR
  --in-place          Run scripts from current folder ($SOURCE_DIR) instead of copying to ~/facilis
  -h, --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            ACTION="status"
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        --purge)
            PURGE=1
            shift
            ;;
        --in-place)
            IN_PLACE=1
            INSTALL_DIR="$SOURCE_DIR"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
    esac
done

unload_agent() {
    if launchctl print "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1; then
        launchctl bootout "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1 || true
    elif [[ -f "$PLIST_DEST" ]]; then
        launchctl unload "$PLIST_DEST" >/dev/null 2>&1 || true
    fi
}

load_agent() {
    unload_agent
    if ! launchctl bootstrap "$GUI_DOMAIN" "$PLIST_DEST" >/dev/null 2>&1; then
        launchctl load "$PLIST_DEST"
    fi
}

show_status() {
    echo "User:          $(id -un) ($HOME)"
    echo "Agent label:   $LABEL"
    echo "Plist path:    $PLIST_DEST"
    echo "Log file:      $LOG_DIR/facilis_cache.log"

    if [[ -f "$PLIST_DEST" ]]; then
        echo "Plist status:  Installed"
    else
        echo "Plist status:  Not installed"
    fi

    if launchctl print "$GUI_DOMAIN/$LABEL" >/dev/null 2>&1 || launchctl list "$LABEL" >/dev/null 2>&1; then
        echo "Launchd state: Loaded ($GUI_DOMAIN/$LABEL)"
    else
        echo "Launchd state: Not loaded"
    fi

    if pgrep -x "fcp" >/dev/null 2>&1; then
        echo "Process state: Running (fcp PID: $(pgrep -x "fcp" | tr '\n' ' '))"
    elif [[ -f "/tmp/com.scn.facilis-cache.lockfile" ]]; then
        local lock_status=0
        /usr/bin/perl -MFcntl=:flock -e '
            open my $lock, "<", $ARGV[0] or exit 2;
            exit 0 if flock($lock, LOCK_EX | LOCK_NB);
            exit(($!{EWOULDBLOCK} || $!{EAGAIN}) ? 1 : 2);
        ' /tmp/com.scn.facilis-cache.lockfile || lock_status=$?
        case "$lock_status" in
            0) echo "Process state: Idle" ;;
            1) echo "Process state: Running (cache lock held)" ;;
            *) echo "Process state: Unknown (cannot inspect cache lock)" ;;
        esac
    else
        echo "Process state: Idle"
    fi

    echo ""
    echo "Currently mounted *_edit volumes:"
    local found=0
    shopt -s nullglob
    for vol in /Volumes/*_edit; do
        if mount | grep -Fq "on ${vol} ("; then
            found=1
            if [[ -d "$vol/Avid MediaFiles" ]]; then
                echo "  - $vol (Avid MediaFiles present)"
            else
                echo "  - $vol (no 'Avid MediaFiles' directory)"
            fi
        fi
    done
    shopt -u nullglob
    if [[ "$found" -eq 0 ]]; then
        echo "  (none currently mounted)"
    fi
}

if [[ "$ACTION" == "status" ]]; then
    show_status
    exit 0
fi

if [[ "$ACTION" == "uninstall" ]]; then
    echo "Unloading $LABEL for user $(id -un)..."
    unload_agent
    if [[ -f "$PLIST_DEST" ]]; then
        rm -f "$PLIST_DEST"
        echo "Removed: $PLIST_DEST"
    else
        echo "Plist not present at $PLIST_DEST"
    fi

    if [[ "$PURGE" -eq 1 && -d "$DEFAULT_INSTALL_DIR" ]]; then
        rm -rf "$DEFAULT_INSTALL_DIR"
        echo "Removed directory: $DEFAULT_INSTALL_DIR"
    fi
    echo "Uninstall complete."
    exit 0
fi

echo "Installing $LABEL for user '$(id -un)'..."

# 1. Copy files to ~/facilis unless already there or --in-place was passed
mkdir -p "$INSTALL_DIR"
if [[ "$SOURCE_DIR" != "$INSTALL_DIR" ]]; then
    cp -f "$SOURCE_DIR/facilis-cache.sh" "$INSTALL_DIR/facilis-cache.sh"
    cp -f "$SOURCE_DIR/fcp" "$INSTALL_DIR/fcp"
    cp -f "$SOURCE_DIR/com.scn.facilis-cache.plist" "$INSTALL_DIR/com.scn.facilis-cache.plist"
    cp -f "$SOURCE_DIR/install.sh" "$INSTALL_DIR/install.sh"
    echo "Copied scripts and fcp binary to: $INSTALL_DIR"
else
    echo "Using existing directory: $INSTALL_DIR"
fi

# 2. Fix permissions and strip macOS Gatekeeper quarantine attributes
chmod +x "$INSTALL_DIR/facilis-cache.sh" "$INSTALL_DIR/fcp" "$INSTALL_DIR/install.sh"
xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true
echo "Cleared quarantine attributes and set executable permissions."

# 3. Create log and LaunchAgents directories (launchd fails silently if log dir is missing)
mkdir -p "$LOG_DIR" "$LAUNCH_AGENTS_DIR"
echo "Ensured log directory exists: $LOG_DIR"

# 4. Write user-specific LaunchAgent plist (scheduled at 20:00 and 03:00)
sed \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__LOG_DIR__|$LOG_DIR|g" \
    "$INSTALL_DIR/com.scn.facilis-cache.plist" > "$PLIST_DEST"

chmod 644 "$PLIST_DEST"
plutil -lint "$PLIST_DEST" >/dev/null

# 5. Load LaunchAgent
load_agent

echo ""
echo "Rollout complete!"
echo "Schedule:      Daily at 20:00 and 03:00"
show_status
