#!/bin/bash   
## Version 1.5.2	
# Special Version for external projects not following our structure
### In order to modify this script to work with different projects, modify the special variables $SINGLE_VOLS, $ABSLT_PATH and $PROJ_NAME.

## command variables
TAR=/usr/bin/tar
RM=/bin/rm
DU=/usr/bin/du
DF=/bin/df
CAT=/bin/cat
MKDIR=/bin/mkdir
AWK=/usr/bin/awk
GREP=/usr/bin/grep
SORT=/usr/bin/sort
if [[ -f /opt/homebrew/bin/mutt ]]; then
    MUTT=/opt/homebrew/bin/mutt
elif [[ -f /usr/local/bin/mutt ]]; then
    RSYNC=/usr/local/bin/mutt
else
    echo "mutt not found!" >> $LOGF
    exit 1
fi
if [[ -f /opt/homebrew/bin/rsync ]]; then
    RSYNC=/opt/homebrew/bin/rsync
elif [[ -f /usr/local/bin/rsync ]]; then
    RSYNC=/usr/local/bin/rsync
else
    echo "rsync not found!" >> $LOGF
    exit 1
fi

## Special variables for the projects
SINGLE_VOLS=`mount | $GREP "production" | $AWK '{print substr($3, 10)}'` # specific for purk
ABSLT_PATH=/Volumes/production/Projects/prk01_tv2_2024/00_PROSJEKTFIL/ # absolute path to project
PROJ_NAME=purk

## Common variables
DEST=/Volumes/temp/_edit_backs
TODAY="$(date '+%y%m%d_%H%M')"
STODAY="$(date '+%y%m%d')"
LOGDIR=~/Library/Logs/
$MKDIR -p $LOGDIR/editvol_bck # this line creates the directory if it does not exist
LOGF=$LOGDIR/editvol_bck/edit_vol_bck"_"$PROJ_NAME"_"$TODAY.log
EXCLUDE_LIST=~/git/editvol_bck/edit_exclude.txt
EMAIL_ADRESS=scntech@shortcutoslo.no

## Script it baby!
echo "Backup started on $HOSTNAME on $TODAY" >> $LOGF
echo "" >> $LOGF

## Self test - check if commands exist
for cmd in $TAR $RM $DU $DF $RSYNC $CAT $MKDIR $AWK $GREP $SORT $MUTT
do
   if ! [ -x "$(command -v $cmd)" ]; then
      echo "Error: $cmd is not installed." >> $LOGF
      exit 1
   fi
done

echo "Self-check passed. All necessary commands are installed." >> $LOGF
echo "" >> $LOGF


# Delete staging copies
echo "Cleaning up staging area" >> $LOGF
$RM -rfv $DEST/$SINGLE_VOLS"_"$PROJ_NAME >> $LOGF
echo "" >> $LOGF


echo "" >> $LOGF
echo "List of volumes to be backed up" >> $LOGF
echo "$SINGLE_VOLS" >> $LOGF #List
echo "" >> $LOGF

## The actual backup
for VOL in $SINGLE_VOLS; do
    echo "" >> $LOGF
    echo "backup of $VOL starts now $TODAY..." >> $LOGF

    # Create destination folder 
    $MKDIR -p $DEST/$VOL"_"$PROJ_NAME

    # tar it off Facilis
    $TAR --exclude-from $EXCLUDE_LIST -czvf $DEST/$VOL"_"$PROJ_NAME/$STODAY"_"$VOL"_"$PROJ_NAME.tar -C "$ABSLT_PATH" . >> $LOGF
    echo "" >> $LOGF

    echo "" >> $LOGF

done

## Some sexy reports
 echo "Size of backups" >> $LOGF
 $DU -sh $DEST/* | $SORT -h >> $LOGF
 echo "" >> $LOGF
 echo "Size of volumes" >> $LOGF
 $DF -h | $GREP production >> $LOGF

# Sync archives from staging to whiterabbit
echo "" >> $LOGF
$RSYNC -rltvh --stats $DEST/* systeminstaller@scnfile02:/Volumes/whiterabbit/zz_scn_edit_bu/ >> $LOGF

echo "" >> $LOGF
echo "Backup is done... " >> $LOGF
$CAT $LOGF

## Sending log to email recipients
$MUTT -s "Backup $TODAY - log for $PROJ_NAME disk" $EMAIL_ADRESS < $LOGF
