## Version 3.1
TODAY="$(date '+%y%m%d-%H%M')"

echo "######################################"
echo "#    Download from SPOTIFY           #"
echo "#                                    #"
echo "# paste link here and press enter :) #"
echo "######################################"
mkdir -p ~/Downloads/$TODAY
read link
spotdl "$link" --format wav --output ~/Downloads/$TODAY --restrict ascii
