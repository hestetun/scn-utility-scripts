#!/bin/bash

## Created by Jorge Enrique Barrera <jorge@shortcutoslo.no>, 2020
## 
## Script to replace special characters in file & misc.


# You can modify these variables.

DESIRED_VIDEO_FORMAT="1080"


# Do not change anything below here.

CMD_ICONV=$(whereis iconv)
CMD_SED=$(whereis sed)
CMD_CP=$(whereis cp)

if [ -z "$1" ]; then
    echo "No argument supplied. Must be a filename."
    echo "usage: $0 <filename>"

elif [ ! -f $1 ]; then
    echo "File not found!"

else
    CURRENT_VIDEO_FORMAT=$($CMD_SED -n 3p $1 | awk '{ print $2 }')

    # First backup file
    $CMD_CP $1 $1.bak

    # Replace special characters 
    $CMD_ICONV -t MACINTOSH//TRANSLIT//IGNORE $1.bak > $1

    # Replace the second column the on third line with the value of
    # DESIRED_VIDEO_FORMAT, if there is a difference.

    if [ $CURRENT_VIDEO_FORMAT != $DESIRED_VIDEO_FORMAT ]; then
        $CMD_SED -i "" "3s/$CURRENT_VIDEO_FORMAT/$DESIRED_VIDEO_FORMAT/" $1
    fi
    echo "Done!"
fi
