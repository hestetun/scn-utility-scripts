#!/bin/bash

# Define your volumes
VOLUME1=/Volumes/./scn_commercial
VOLUME2=/Volumes/./commercial_src

# Define excluded directories
EXCLUDE_DIRS="--exclude=master --exclude=grade --exclude=online --exclude=audio --exclude=tmp --exclude=vfx --exclude=.DS_Store"

# Check if the volumes are mounted
if ! mount | grep "${VOLUME1}" > /dev/null; then
    echo "${VOLUME1} not mounted!"
    exit 1
fi

if ! mount | grep "${VOLUME2}" > /dev/null; then
    echo "${VOLUME2} not mounted!"
    exit 1
fi

# Ask the user for project names
echo "Enter project names, separated by spaces:"
read -a PROJECTS

# Ask the user for destination volume
echo "Enter destination volume, cmd, alt + c on disk you want to use"
read DESTINATION

# Execute rsync command for each project
for PROJ in "${PROJECTS[@]}"; do
    mkdir -p "$DESTINATION/$PROJ"  # Create the destination directory if it doesn't exist
    rsync -rltvhR --stats --progress ${EXCLUDE_DIRS} "$VOLUME1/scn_commercial/$PROJ/adv/*" "$VOLUME2/_resolve_editproxy/ProxyMedia/$PROJ" "$DESTINATION/$PROJ"
done
