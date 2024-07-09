#!/bin/bash
## Created by Ole-Andrè Hestetun   
version="1.0.0"	

## command variables
TAR=/usr/bin/tar
DU=/usr/bin/du
DF=/bin/df
CAT=/bin/cat
MKDIR=/bin/mkdir
GREP=/usr/bin/grep
SORT=/usr/bin/sort


## Common variables
DEST=/Volumes/temp/_edit_backs
TODAY="$(date '+%y%m%d_%H%M')"
STODAY="$(date '+%y%m%d')"
LOGDIR=~/Library/Logs/
$MKDIR -p $LOGDIR/editvol_bck # this line creates the directory if it does not exist
LOGF=$LOGDIR/editvol_bck/tr_edit_vol_bck_$TODAY.log
EXCLUDE_LIST=~/git/scn-utility-scripts/tr_edit_exclude.txt
EMAIL_ADRESS=scntech@shortcutoslo.no
VOLS=$(TR_PROJECT)

## Script it baby!
echo "Backup started on $HOSTNAME on $TODAY" >> $LOGF
echo "v$version" >> $LOGF
echo "" >> $LOGF

## Self test - check if commands exist
for cmd in $TAR $DU $DF $CAT $MKDIR $GREP $SORT $MUTT
do
   echo "Checking if $cmd exists and is executable..." >> $LOGF
   if ! [ -x "$(command -v $cmd)" ]; then
      echo "Error: $cmd is not installed." >> $LOGF
      exit 1
   fi
done

echo "Self-check passed. All necessary commands are installed." >> $LOGF
echo "" >> $LOGF

echo "" >> $LOGF
echo "List of volumes to be backed up" >> $LOGF
echo "$VOLS" >> $LOGF #List
echo "" >> $LOGF

## The actual backup
for VOL in $VOLS; do
    echo "" >> $LOGF
    echo "backup of $VOL starts now $TODAY..." >> $LOGF

    # Create destination folder 
    $MKDIR -p $DEST/$VOL

    # tar it off Facilis
    $TAR --exclude-from $EXCLUDE_LIST -czvf $DEST/$VOL/$STODAY"_"$VOL.tar -C "/Volumes/$VOL/editorial/project/" . >> $LOGF

    echo "" >> $LOGF

done

## Some sexy reports
 echo "Size of backups" >> $LOGF
 $DU -sh $DEST/* | $SORT -h >> $LOGF
 echo "" >> $LOGF
 echo "Size of volumes" >> $LOGF
 $DF -h | $GREP $VOLS >> $LOGF


echo "" >> $LOGF
echo "Backup is done... " >> $LOGF
$CAT $LOGF

## Sending log to email recipients
$MUTT -s "Backup $TODAY - log for TR project" $EMAIL_ADRESS < $LOGF
