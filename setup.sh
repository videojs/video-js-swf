#!/bin/bash

# Setup the project, which copies over the files from Video.js.  You'll still
# need to build the latest SWF after this using either build.sh or an IDE.

# From a shell prompt: sh setup.sh video-js-location

video_js=$1
if [ -z "$video_js" ]
then
  video_js="$VIDEO_JS"
  if [ -z "$video_js" ]
  then
    echo "setup.sh video_js_dir"
    exit 1;
  fi
fi

mkdir -p bin-debug
cp -r "$video_js/dist/video-js/" bin-debug
rm bin-debug/video-js.swf
cp -f demo.html bin-debug/

mkdir -p bin-release
cp -rf bin-debug/ bin-release/
sed -i.bak 's/VideoJS.swf/video-js.swf/' bin-release/demo.html


