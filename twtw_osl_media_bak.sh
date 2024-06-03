#!/bin/bash   
## Created by Ole-Andrè Hestetun

## Requires DEST vol login info to be saved in keychain, the VOLS to be mounted beforehand and homebrew rsync

## Common Variables
MKDIR=/bin/mkdir
OSASCRIPT=/usr/bin/osascript
UMOUNT=/sbin/umount

TODAY="$(date '+%y%m%d_%H%M')"
STODAY="$(date '+%y%m%d')"
LOGDIR=~/Library/Logs/
$MKDIR -p $LOGDIR/twtw_osl_media # this line creates the directory if it does not exist
LOGF=$LOGDIR/twtw_osl_media/edit_vol_bck_extras_$TODAY.log
EMAIL_ADRESS=scntech@shortcutoslo.no
HOSTNAME=/bin/hostname
VOLS=(
"filmlance_scn_edit_oslo_media"
)

if [ -f /opt/homebrew/bin/rsync ]; then
    RSYNC=/opt/homebrew/bin/rsync
elif [ -f /usr/bin/rsync ]; then
    RSYNC=/usr/bin/rsync
else
    echo "rsync not found!" >> $LOGF
    exit 1
fi
if [[ -f /opt/homebrew/bin/mutt ]]; then
    MUTT=/opt/homebrew/bin/mutt
elif [[ -f /usr/local/bin/mutt ]]; then
    MUTT=/usr/local/bin/mutt
else
    echo "mutt not found!" >> $LOGF
    exit 1
fi

## Mount backup storage using SMB. smb://scn-stor04/twtw_bu
$OSASCRIPT -e 'mount volume "smb://scn-stor04/twtw_bu"'

## Check if backup storage is mounted
DEST=$(mount | grep "//write@scn-stor04/twtw_bu" | awk '{print $3}')
if [ -z "$DEST" ]; then
    echo "ERROR, DEST backup storage is not mounted!" >> $LOGF
    exit 1
fi

## Check if all volumes are mounted
for VOL in "${VOLS[@]}"; do
    if ! mount | grep -q "$VOL"; then
        echo "ERROR, src volume $VOL is not mounted!" >> $LOGF
        exit 1
    fi
done

## Back it up
for VOL in "${VOLS[@]}"; do
    echo "backup of $VOL starts now $TODAY on $(HOSTNAME)..." >> $LOGF
    echo "" >> $LOGF
    echo "" >> $LOGF

    # Create destination folder 
    backup_dir="${DEST}/${VOL}"
    if [ ! -d "$backup_dir" ]; then
        $MKDIR -p "$backup_dir"
    fi

    # rsync it it
    $RSYNC -avh --stats "/Volumes/$VOL/" "$backup_dir" >> $LOGF
done

## Unmount the backup storage
$UMOUNT "$DEST"

## Sending log to email recipients
$MUTT -s "Backup $TODAY - log for TWTW media" $EMAIL_ADRESS < $LOGF