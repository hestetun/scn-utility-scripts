#!/bin/bash

# variables
SRC=/Volumes/scn_ftr_03/scn_ftr_03/./wayhome/ftr/vfx/comp
DEST=/Volumes/temp/
TODAY="$(date '+%y%m%d_%H%M')"
STODAY="$(date '+%y%m%d')"
LOGDIR=/Volumes/temp/wayhome/_logs
LOGF=$LOGDIR/$TODAY_logfile.log

# logdir creation
mkdir -p $LOGDIR

## some checks
if [[ -f /opt/homebrew/bin/rsync ]]; then
    RSYNC=/opt/homebrew/bin/rsync
elif [[ -f /usr/local/bin/rsync ]]; then
    RSYNC=/usr/local/bin/rsync
else
    echo "rsync not found!" >> $LOGF
    exit 1

## Script it baby!
echo "VFX-comp sync started on $HOSTNAME on $TODAY" >> $LOGF
echo "" >> $LOGF
echo "🏎️ Synchronizing files from $SRC to $DEST 🏎️" >> $LOGF
echo "" >> $LOGF
echo "" >> $LOGF

## rsync command
$RSYNC -rltvhR --info=progress2  "$SRC" "$DEST" >> $LOGF

## Some sexy reports
echo "Size of temp-disk" >> $LOGF
du -shc $DEST/* | sort -h >> $LOGF
echo "" >> $LOGF

cat $LOGF | mail -s "Wayhome: VFX-comp sync is done $STODAY" scntech@shortcutoslo.no ase@shortcutoslo.no