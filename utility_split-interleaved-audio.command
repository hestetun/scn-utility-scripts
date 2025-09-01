#!/bin/bash

read -p "Enter the input filename: " inputfile

# Remove single quotes from the input filename if present
inputfile=$(echo "$inputfile" | sed "s/'//g")

# Check if input file exists
if [ ! -f "$inputfile" ]; then
    echo "Error: Input file '$inputfile' does not exist."
    exit 1
fi

read -p "Enter the output folder name (default: multiple_mono): " output_folder

# Use default folder name if nothing was entered
if [ -z "$output_folder" ]; then
    output_folder="multiple_mono"
fi

# Extract the base filename and directory path
dir=$(dirname "$inputfile")
filename=$(basename "$inputfile")
base_name="${filename%.*}"

# Create the specified output directory within the path of the input file
output_dir="${dir}/${output_folder}"
mkdir -p "$output_dir"

# Detect the channel layout of the input file
audio_stream=$(ffmpeg -i "$inputfile" 2>&1 | grep 'Stream.*Audio')
echo "Audio stream info: $audio_stream"

# Extract channel layout - look for patterns like "5.1", "7.1", "stereo", etc.
if echo "$audio_stream" | grep -q "5\.1"; then
    channel_layout="5.1"
elif echo "$audio_stream" | grep -q "7\.1"; then
    channel_layout="7.1"
elif echo "$audio_stream" | grep -q "stereo"; then
    channel_layout="stereo"
else
    # Fallback: try to extract any decimal pattern
    channel_layout=$(echo "$audio_stream" | grep -oE '[0-9]+\.[0-9]+')
fi

echo "Detected channel layout: $channel_layout"

# Perform the channel splitting and convert to 24-bit
if [ "$channel_layout" == "5.1" ]; then
    echo "Processing as 5.1 surround..."
    if ! ffmpeg -i "$inputfile" -filter_complex \
    "channelsplit=channel_layout=5.1[FL][FR][FC][LFE][BL][BR]" \
    -map "[FL]" -c:a pcm_s24le "${output_dir}/${base_name}.L.wav" \
    -map "[FR]" -c:a pcm_s24le "${output_dir}/${base_name}.R.wav" \
    -map "[FC]" -c:a pcm_s24le "${output_dir}/${base_name}.C.wav" \
    -map "[LFE]" -c:a pcm_s24le "${output_dir}/${base_name}.LFE.wav" \
    -map "[BL]" -c:a pcm_s24le "${output_dir}/${base_name}.Ls.wav" \
    -map "[BR]" -c:a pcm_s24le "${output_dir}/${base_name}.Rs.wav"; then
        echo "Error: ffmpeg processing failed."
        exit 1
    fi
elif [ "$channel_layout" == "7.1" ]; then
    echo "Processing as 7.1 surround..."
    if ! ffmpeg -i "$inputfile" -filter_complex \
    "channelsplit=channel_layout=7.1[FL][FR][FC][LFE][BL][BR][SL][SR]" \
    -map "[FL]" -c:a pcm_s24le "${output_dir}/${base_name}.L.wav" \
    -map "[FR]" -c:a pcm_s24le "${output_dir}/${base_name}.R.wav" \
    -map "[FC]" -c:a pcm_s24le "${output_dir}/${base_name}.C.wav" \
    -map "[LFE]" -c:a pcm_s24le "${output_dir}/${base_name}.LFE.wav" \
    -map "[BL]" -c:a pcm_s24le "${output_dir}/${base_name}.Lsr.wav" \
    -map "[BR]" -c:a pcm_s24le "${output_dir}/${base_name}.Rsr.wav" \
    -map "[SL]" -c:a pcm_s24le "${output_dir}/${base_name}.Lss.wav" \
    -map "[SR]" -c:a pcm_s24le "${output_dir}/${base_name}.Rss.wav"; then
        echo "Error: ffmpeg processing failed."
        exit 1
    fi
elif [ "$channel_layout" == "stereo" ] || [ "$channel_layout" == "2.0" ]; then
    echo "Processing as stereo..."
    if ! ffmpeg -i "$inputfile" -filter_complex \
    "channelsplit=channel_layout=stereo[FL][FR]" \
    -map "[FL]" -c:a pcm_s24le "${output_dir}/${base_name}.L.wav" \
    -map "[FR]" -c:a pcm_s24le "${output_dir}/${base_name}.R.wav"; then
        echo "Error: ffmpeg processing failed."
        exit 1
    fi
else
    echo "Unsupported channel layout: $channel_layout"
    exit 1
fi

echo "Channel splitting completed successfully!"

