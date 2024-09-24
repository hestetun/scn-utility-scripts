#!/bin/bash

# Define your volumes
VOLUME1=/Volumes/scn_ftr_01/scn_ftr_01/askepote
VOLUME2=/Volumes/scn_ftr_05/scn_ftr_05/kvitebjorn
DESTINATION=/Volumes/resolve_cache

# Define excluded directories
EXCLUDE_DIRS="--exclude=master --exclude=tmp --exclude=.DS_Store --exclude=_reference --exclude=audio"

# SSH user and host
SSH_USER=systeminstaller
SSH_HOST=scnfile02

# Get current date and time for logs
TODAY="$(date '+%y%m%d_%H%M')"
STODAY="$(date '+%y%m%d')"
LOGDIR=~/Library/Logs/
mkdir -p $LOGDIR/biancasync

# Set the log file path with the short volume name (placeholder until choice is made)
LOGF=$LOGDIR/biancasync/biancasync_$TODAY.log

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGF"
}

# Check for necessary commands
if [[ -f /opt/homebrew/bin/rsync ]]; then
    RSYNC=/opt/homebrew/bin/rsync
elif [[ -f /usr/local/bin/rsync ]]; then
    RSYNC=/usr/local/bin/rsync
else
    log "rsync not found!"
    exit 1
fi

# Helper function to print usage
usage() {
    echo "Usage: $0 [a|k]"
    echo "  a - Sync Askepote"
    echo "  k - Sync Kvitebjorn"
    exit 1
}

# Check for command-line arguments or prompt user input
if [ $# -gt 0 ]; then
    choice=$1
else
    read -p "Do you want to copy Askepote (a) or Kvitebjorn (k)? " choice
fi

# Validate and set up project variables based on user choice
case "$choice" in
    a)
        PROJ="askepote"
        SRC=$VOLUME1
        ;;
    k)
        PROJ="kvitebjorn"
        SRC=$VOLUME2
        ;;
    *)
        echo "Invalid choice!"
        usage
        ;;
esac

# Update the log file path with the project name
LOGF=$LOGDIR/biancasync/biancasync_${PROJ}_$TODAY.log

# Check if the volumes are mounted on the remote SSH device
if ! ssh "$SSH_USER@$SSH_HOST" "[ -f $SRC/_${PROJ}.txt ]"; then
    log "${SRC} not mounted on remote device!"
    log "Exiting with error."
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DESTINATION/$PROJ"

# Perform the rsync operation
log "Starting sync for $PROJ..."
$RSYNC -rltvh --stats --progress --info=progress2 $EXCLUDE_DIRS -e ssh "$SSH_USER@$SSH_HOST:$SRC" "$DESTINATION/$PROJ" | tee -a "$LOGF"

if [ $? -eq 0 ]; then
    log "Syncing completed successfully."
else
    log "Syncing encountered errors."
fi

exit 0
