#!/bin/bash

base_dir="/Volumes/scn_ftr_04/scn_ftr_04/lapalma"
log_dir="/Users/oah/Library/Logs/SCN"
timestamp=$(date +"%y%m%d_%H%M%S")
last_folder=$(basename "$base_dir")
file_prefix="scn_vfx_shot_count_${last_folder}_${timestamp}"
log_file="$log_dir/${file_prefix}.log"
csv_file="$log_dir/${file_prefix}.csv"

# Ensure log directory exists
mkdir -p "$log_dir"

# Collect the detailed list of directories; log the real-time output and process awk to CSV
find "$base_dir" -type d -name "comp" -exec find {} -type d \; | tee "$log_file" | awk -F/ '{print $(NF-7)","$(NF-2)","$NF}' > "$csv_file"

# Generate report
output=$(mktemp)  # Temporary file to store output

{
    episodes=$(cut -d, -f1 "$csv_file" | sort | uniq)
    
    for episode in $episodes; do
        echo "#### Episode $episode"
        count=$(grep "^$episode," "$csv_file" | wc -l)
        echo "Total Shots:       $count"
        echo "Comps:"
        
        shots=$(grep "^$episode," "$csv_file" | awk -F, '{print $3}')
        echo -e "$shots\n"
    done

} | tee -a "$output" "$log_file"  # Output to both terminal and log file

# Output the summary to the terminal
cat "$output"

echo "Log file created at: $log_file"
echo "CSV file created at: $csv_file"