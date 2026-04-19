#!/bin/bash
# Get the timestamp for the log
echo "--- Backup started at $(date) ---"

SOURCE_VOL="/Volumes/ekte-kjarlighet_edit"

if ! mount | grep -q "on $SOURCE_VOL "; then
    echo "--- Error: Volume '$SOURCE_VOL' not found. Aborting at $(date) ---"
    exit 1
fi

# Run the fcp command
# Using absolute paths is safer for scheduled tasks
/Users/fante/facilis/fcp -q "/Volumes/ekte-kjarlighet_edit/Avid MediaFiles" -r

echo "--- Backup finished at $(date) ---"

