#!/bin/bash

## Created by Jorge Enrique Barrera <jorge@shortcutoslo.no>, 2020
## Modified by tech to support latest macOS, 2023
## Script to replace special characters in file & misc.

# You can modify these variables.
DESIRED_VIDEO_FORMAT="1080"

# Do not change anything below here.

CMD_ICONV=$(command -v iconv)
CMD_SED=$(command -v sed)
CMD_CP=$(command -v cp)

if [ -z "$1" ]; then
    echo "No argument supplied. Must be a filename."
    echo "usage: $0 <filename>"
elif [ ! -f "$1" ]; then
    echo "File not found!"
else
    BACKUP_FILENAME="$1".bak
    CURRENT_VIDEO_FORMAT=$($CMD_SED -n 3p "$1" | awk '{ print $2 }')

    # Create a backup by copying the original file
    $CMD_CP "$1" "$BACKUP_FILENAME"

    # Replace special characters
    $CMD_ICONV -t MACINTOSH//TRANSLIT//IGNORE "$BACKUP_FILENAME" > "$1"

    # Replace the second column on the third line with the value of
    # DESIRED_VIDEO_FORMAT, if there is a difference.
    if [ "$CURRENT_VIDEO_FORMAT" != "$DESIRED_VIDEO_FORMAT" ]; then
        $CMD_SED -i "" "3s/$CURRENT_VIDEO_FORMAT/$DESIRED_VIDEO_FORMAT/" "$1"
    fi
    echo "Done! Original file backed up as $BACKUP_FILENAME"
fi
