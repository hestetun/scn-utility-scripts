#!/bin/bash

# Check if exrinfo is installed
if ! command -v exrinfo &> /dev/null
then
    echo "exrinfo could not be found, please install OpenEXR utilities"
    exit 1
fi

# Function to process an EXR file
process_exr() {
    exrfile=$1
    output=$(exrinfo -v -a $exrfile 2>&1)
    if [ $? -ne 0 ]
    then
        # Echo the error message directly
        echo "ERROR processing '$exrfile': $output"
        return 1
    else
        echo "$output" | awk -F: '/compression|channels|displayWindow/ { gsub(/^[ \t]+/, "", $2); print $1 ": " $2}'
        return 0
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

script_dir=$(dirname $0)
dir=$(echo $dir | sed 's:/*$::') # Remove any trailing slash from the directory path
mkdir -p "${script_dir}/_logs" # Create _logs directory if it doesn't exist
dir_name=$(basename "$dir")
today=$(date +%Y%m%d)
log_file="${script_dir}/_logs/${dir_name}_${today}.log"

# Show a message that the directory is being processed
echo "🏎️ VFX-comp sync started on $HOSTNAME on ${today}🏎️ \n\nProcessing $dir for EXRs" | tee -a "${log_file}"

# Find all EXR files in the directory and its subdirectories, and sort them
exrfiles=$(find "$dir" -type f -name '*.exr' | sort -V)

# Initialize an empty string for errors
errors=""

# Process each file
sequence_name=""
for file in $exrfiles
do
    base_name=$(basename $file)
    sequence=$(echo $base_name | sed 's/\.[0-9]\{4\}\.exr//g')

    if [[ "$sequence" != "$sequence_name" ]]
    then
        sequence_name=$sequence
        prop=$(process_exr $file)
        if [ $? -ne 0 ]
        then
            # If process_exr returned an error, add prop to the errors string and continue to the next file
            errors+="$prop\n"
            continue
        fi
        properties="$sequence_name\n$prop"
        echo "$properties" | sed 's/-e //g' | tee -a "${log_file}"
    else
        new_prop=$(process_exr $file)
        if [ $? -ne 0 ]
        then
            # If process_exr returned an error, add new_prop to the errors string and continue to the next file
            errors+="$new_prop\n"
            continue
        fi
        if [[ "$new_prop" != "$prop" ]]
        then
            echo "Metadata inconsistency found in sequence $sequence_name" | tee -a "${log_file}"
        fi
    fi
done

# After your main loop...
if [ -n "$errors" ]
then
    echo "\nErrors occurred while processing EXR files:\n$errors" | tee -a "${log_file}"
fi

# Success message
echo "All sequences have been processed. Check the log file ${log_file} for the result.\n\n\n" | tee -a "${log_file}"

exit 0