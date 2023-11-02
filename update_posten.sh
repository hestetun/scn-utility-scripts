#!/bin/bash

# Define your volumes
VOLUME1=/Volumes/scn_commercial
VOLUME2=/Volumes/commercial_src
PROJ=extra_jul_2023_einarfilm_201106126_231102

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

# Execute rsync command
rsync -rltvhR --stats --progress ${EXCLUDE_DIRS} /Volumes/./scn_commercial/scn_commercial/$PROJ/adv/* /Volumes/./commercial_src/_resolve_editproxy/ProxyMedia/$PROJ /Volumes/Magnus-klippedisk/extra_jul
