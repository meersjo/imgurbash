#!/bin/bash

# 20160426  5.0  vegivamp  Update for api v3.
# imgur script by Bart Nagel <bart@tremby.net>
# version 4
# I release this into the public domain. Do with it what you will.

# Required: curl
#
# Optional: xsel or xclip for automatically putting the URLs on the X selection 
# for easy pasting
#
# Instructions:
# Put it somewhere in your path and maybe rename it:
# 	mv ~/Downloads/imgurbash.sh ~/bin/imgur
# Make it executable:
# 	chmod +x ~/bin/imgur
# Upload an image:
# 	imgur images/hilarious/manfallingover.jpg
# Upload multiple images:
# 	imgur images/delicious/cake.png images/exciting/bungeejump.jpg
# The URLs will be displayed (and the delete page's URLs will be displayed on 
# stderr). If you have xsel or xclip the URLs will also be put on the X 
# selection, which you can usually paste with a middle click.


# Since image delete is a DELETE request in api v3, we no longer print that by default.
# Turn on printing of delete commandlines (NOT just URLs!) by setting showdelete=1
showdelete=0

# Client ID
clientid='ec144c406a59670'

# Function to output usage instructions
function usage {
	echo "Usage: $(basename $0) <filename> [<filename> [...]]" >&2
	echo "Upload images to imgur and output their new URLs to stdout. Each one's" >&2
	echo "delete page is output to stderr between the view URLs." >&2
	echo "If xsel or xclip is available, the URLs are put on the X selection for" >&2
	echo "easy pasting." >&2
}

# Function that returns the value of a single JSON element.
# Overly simplistic, but prevents more dependencies.
function jsonvalue {
  input="$1"; shift
  key="$1";   shift
  
  echo "$input" | sed " s/^.*[{,]\"${key}\":\"\?//;
                        s/\"\?[,}].*$//;
                        s/\\\\\//\//g;"
}

# check client ID has been entered
if [ "$clientid" = "Your client ID" ]; then
	echo "You first need to edit the script and put your API key in the variable near the top." >&2
	exit 15
fi

# check arguments
if [ "$1" = "-h" -o "$1" = "--help" ]; then
	usage
	exit 0
elif [ $# == 0 ]; then
	echo "No file specified" >&2
	usage
	exit 16
fi

# check curl is available
type curl >/dev/null 2>/dev/null || {
	echo "Couln't find curl, which is required." >&2
	exit 17
}

clip=""
errors=false

# loop through arguments
while [ $# -gt 0 ]; do
	file="$1"
	shift

	# check file exists
	if [ ! -f "$file" ]; then
		echo "file '$file' doesn't exist, skipping" >&2
		errors=true
		continue
	fi

	# upload the image
	response=$(curl -H "Authorization: Client-ID $clientid" -F "image=@$file" \
		https://api.imgur.com/3/upload 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Upload failed" >&2
		errors=true
		continue
	elif [ $(jsonvalue "$response" 'status') -ne '200' ]; then
		echo -n "Error message from imgur: " >&2
		jsonvalue "$response" 'error' >&2
		errors=true
		continue
	fi

	# parse the response and output our stuff
        url=$(jsonvalue "$response" 'link')
	echo $url

        if [ $showdelete -eq 1 ]; then
          deletehash=$(jsonvalue "$response" 'deletehash')
          echo "Delete command:" >&2
          echo -n "    curl -XDELETE -H 'Authorization: Client-ID " >&2
          echo -n $clientid >&2
          echo -n "' https://api.imgur.com/3/image/${deletehash}" >&2
        fi

	# append the URL to a string so we can put them all on the clipboard later
	clip="$clip$url\n"
done

# put the URLs on the clipboard if we have xsel or xclip
if [ $DISPLAY ]; then
	{ type xsel >/dev/null 2>/dev/null && echo -ne "$clip" | xsel; } \
		|| { type xclip >/dev/null 2>/dev/null && echo -ne "$clip" | xclip; } \
		|| echo "Haven't copied to the clipboard: no xsel or xclip" >&2
else
	echo "Haven't copied to the clipboard: no \$DISPLAY" >&2
fi

if $errors; then
	exit 1
fi
