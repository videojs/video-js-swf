#!/bin/bash

# See README.md for instructions

pwd=`pwd`
video_js="$pwd/../video.js"
flex_sdk=/Applications/Flex

# use command-line parameters if the default locations
# aren't available
if [ ! -d "$video_js" ]
then
  video_js=$1
fi
if [ ! -d "$flex_sdk" ]
then
  flex_sdk=$2
fi

# if we needed command-line parameters and didn't get them,
# complain about it
if [ -z "$video_js" ] || [ -z "$flex_sdk" ]
then
  echo "Usage: setup.sh video_js_dir flex_sdk_dir"
  exit 1
fi

# complain about the incorrect directories passed in
if [ ! -d "$video_js" ]
then
  echo "video.js not found at $video_js"
  exit 1
fi
if [ ! -d "$flex_sdk" ]
then
  echo "Flex SDK not found at $flex_sdk"
  exit 1
fi

# and now we can get started, echoing out what we're doing

echo "Compiling bin-debug/VideoJS.swf..."
$flex_sdk/bin/mxmlc ./src/VideoJS.as -o ./bin-debug/VideoJS.swf -target-player=10.3 -library-path+=libs/HLSProvider.swc

echo "Copying VideoJS.swf to $video_js/src/swf/video-js.swf..."
cp bin-debug/VideoJS.swf "$video_js/src/swf/video-js.swf"

echo "Copying flash_demo.html and video-js.swf into $video_js/dist/video-js/..."
cp bin-debug/VideoJS.swf "$video_js/dist/video-js/video-js.swf"
cp flash_demo.html "$video_js/dist/video-js"

echo "Finished."