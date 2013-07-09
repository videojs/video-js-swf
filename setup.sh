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
  echo 'video.js not found at ' "$video_js"
  exit 1
fi
if [ ! -d "$flex_sdk" ]
then
  echo 'Flex SDK not found at ' "$flex_sdk"
  exit 1
fi

echo "Downloading the Flash 10.3 playerglobal.swc..." 
mkdir -p "$flex_sdk/frameworks/libs/player/10.3"
curl -o "$flex_sdk/frameworks/libs/player/10.3/playerglobal.swc" "http://fpdownload.macromedia.com/get/flashplayer/updaters/10/playerglobal10_3.swc"

echo "Setting up Video.js and demo files in bin-debug..."
mkdir -p bin-debug
cp -r "$video_js/dist/video-js/" bin-debug
rm bin-debug/video-js.swf
cp -f demo.html bin-debug/

echo "Setting up Video.js and demo files in bin-release..."
mkdir -p bin-release
cp -rf bin-debug/ bin-release/
sed -i.bak 's/VideoJS.swf/video-js.swf/' bin-release/demo.html

echo "Finished."
