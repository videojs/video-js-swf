#!/bin/bash

# See README.md for instructions

video_js=$1
flex_sdk=$2

if [ -z "$video_js" ] || [ -z "$flex_sdk" ]
then
  echo "Usage: setup.sh video_js_dir flex_sdk_dir"
  exit 1
fi
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

echo "Compiling video-js.swf..."

$flex_sdk/bin/mxmlc ./src/VideoJS.as -o ./bin-release/video-js.swf -target-player=10.3

echo "Copying SWF into $video_js/src/swf..."

cp bin-release/video-js.swf "$video_js/src/swf/video-js.swf"

echo "Finished."