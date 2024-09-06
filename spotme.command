## Version 2.1
echo "######################################"
echo "#    Download from SPOTIFY           #"
echo "#                                    #"
echo "# paste link here and press enter :) #"
echo "######################################"
read link
spotdl "$link" --format wav --output ~/Downloads/ --restrict ascii

# error "Message"
function pornhub() {
  osascript <<EOT
    tell app "System Events"
      display dialog "$1" buttons {"OK"} default button 1 with icon caution with title "$(basename $0)"
      return  -- Suppress result
    end tell
EOT
}

pornhub "$link was downloaded to your box of treasures!!!"