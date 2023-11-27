#!/bin/bash

# Check if exrinfo is installed
if ! command -v exrinfo &> /dev/null
then
    echo "exrinfo could not be found, please install OpenEXR utilities"
fi

# Function to process an EXR file
process_exr() {
    exrfile=$1
    output=$(exrinfo -v -a $exrfile | awk -F: '/compression|channels|displayWindow/ { gsub(/^[ \t]+/, "", $2); print $1 ": " $2}')
    if [ $? -ne 0 ]
    then
        echo "$exrfile is corrupt" >> "${corrupt_file}"
    else
        echo "$output"
    fi
}

# Main script
if [ $# -eq 0 ]
then
    echo "No directory provided. Please enter a directory:"
    read dir
else
    dir=$1
fi

# Remove any trailing slash from the directory path
dir=$(echo $dir | sed 's:/*$::')

# Show a message that the directory is being processed
echo "Processing $dir for EXRs"

# Name of the corrupt files list
today=$(date +%Y%m%d)
corrupt_file="${dir}_corrupt_${today}.txt"

# Find all EXR files in the directory and its subdirectories
exrfiles=$(find "$dir" -type f -name '*.exr')

# Process each file
sequence_name=""
properties=""
for file in $exrfiles
do
    base_name=$(basename $file)
    sequence=$(echo $base_name | sed 's/\.[0-9]\{4\}\.exr//g')

    if [[ "$sequence" != "$sequence_name" ]]
    then
        sequence_name=$sequence
        prop=$(process_exr $file)
        properties="$sequence_name\n$prop"
        echo "$properties"
    else
        new_prop=$(process_exr $file)
        if [[ "$new_prop" != "$prop" ]]
        then
            echo "Metadata inconsistency found in sequence $sequence_name"
        fi
    fi
done

# Echo the corrupt files
if [ -f "${corrupt_file}" ]
then
    echo "Corrupt files listed in: ${corrupt_file}"
fi

# Success message
echo "All sequences have been processed and verified."

exit 0