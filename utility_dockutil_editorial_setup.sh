#!/bin/bash

# Determine the dockutil path
if [[ -x "/opt/homebrew/bin/dockutil" ]]; then
    CMD_DOCKUTIL="/opt/homebrew/bin/dockutil"
elif [[ -x "/usr/local/bin/dockutil" ]]; then
    CMD_DOCKUTIL="/usr/local/bin/dockutil"
else
    echo "dockutil not found. Please install dockutil and try again."
    exit 1
fi

# Get the currently logged-in user
current_user=$(whoami)

# Function to add application to Dock if it exists
add_to_dock() {
  local app_path=$1
  local app_name=$2
  if [[ -d "$app_path" ]]; then
    echo "Adding $app_name to the Dock."
    $CMD_DOCKUTIL --add "$app_path" --no-restart
  else
    echo "$app_name is not installed."
  fi
}

# Function to add optional application to Dock if it exists (no error message)
add_optional_to_dock() {
  local app_path=$1
  if [[ -d "$app_path" ]]; then
    echo "Adding optional app $(basename "$app_path") to the Dock."
    $CMD_DOCKUTIL --add "$app_path" --no-restart
  fi
}

# Clear out the Dock
echo "Clearing the Dock."
$CMD_DOCKUTIL --remove all --no-restart

# Add important applications to the Dock

# Google Chrome
if [[ -d "/Users/$current_user/Applications/Google Chrome.app" ]]; then
  add_to_dock "/Users/$current_user/Applications/Google Chrome.app" "Google Chrome"
elif [[ -d "/Applications/Google Chrome.app" ]]; then
  add_to_dock "/Applications/Google Chrome.app" "Google Chrome"
fi

# Safari
add_to_dock "/Applications/Safari.app" "Safari"

# Calendar
add_to_dock "/System/Applications/Calendar.app" "Calendar"

# Notes
add_to_dock "/System/Applications/Notes.app" "Notes"

# System Settings
add_to_dock "/System/Applications/System Settings.app" "System Settings"

# Add optional applications to the Dock

# Facilis Hub Client Console
add_optional_to_dock "/Applications/Facilis Hub Client Console.app"

# Avid Media Composer
add_optional_to_dock "/Applications/Avid Media Composer/AvidMediaComposer.app"

# Adobe Premiere Pro (check for the latest version)
latest_premiere_pro=""
latest_premiere_pro_year=0
for app_path in /Applications/Adobe\ Premiere\ Pro\ */Adobe\ Premiere\ Pro\ *.app; do
  app_name=$(basename "$app_path")
  if [[ "$app_name" =~ Adobe\ Premiere\ Pro\ ([0-9]{4})\.app$ ]]; then
    year=${BASH_REMATCH[1]}
    if (( year > latest_premiere_pro_year )); then
      latest_premiere_pro="$app_path"
      latest_premiere_pro_year=$year
    fi
  fi
done

if [[ -n "$latest_premiere_pro" ]]; then
  add_optional_to_dock "$latest_premiere_pro"
fi

# DaVinci Resolve
add_optional_to_dock "/Applications/DaVinci Resolve/DaVinci Resolve.app"

# Blackmagic Fusion
add_optional_to_dock "/Applications/Blackmagic Fusion 18/Fusion.app"

# Soundly
add_optional_to_dock "/Applications/Soundly.app"

# Shutter Encoder
add_optional_to_dock "/Applications/Shutter Encoder.app"

# Restart the Dock to apply changes
killall Dock

echo "Dock setup completed."