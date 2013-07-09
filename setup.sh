#!/bin/bash

# Setup the project, which copies over the files from Video.js.  You'll still
# need to build the latest SWF after this using either build.sh or an IDE.

# From a shell prompt: sh setup.sh video-js-location

video_js=$1
flex_sdk=$2
start_dir=`pwd`

if [ -z "$video_js" ] && [ -z "$flex_sdk" ] ;
then
  video_js="$VIDEO_JS"
  if [ -z "$video_js" ]
  then
    echo "Usage: setup.sh video_js_dir flex_sdk_dir" ;
    exit 1 ;
  fi
fi

if [ ! -d "$video_js" ] ;
then
  echo 'No Video.js found at ' "$video_js" ;
  exit 1 ;
fi

if [ ! -d "$flex_sdk" ] ;
then
  echo 'No Flex SDK found at ' "$flex_sdk" ;
  exit 1 ;
fi

echo "Downloading the Flash 10.3 playerglobal.swc..." ;
cd "$flex_sdk" ;
mkdir -p frameworks/libs/player/10.3 ;
curl -o frameworks/libs/player/10.3/playerglobal.swc "http://fpdownload.macromedia.com/get/flashplayer/updaters/10/playerglobal10_3.swc" ;

echo "Setting up Video.js and demo files in bin-debug..."
cd "$start_dir" ;
mkdir -p bin-debug ;
cp -r "$video_js/dist/video-js/" bin-debug ;
rm bin-debug/video-js.swf ;
cp -f demo.html bin-debug/ ;

echo "Setting up Video.js and demo files in bin-release..."
mkdir -p bin-release ;
cp -rf bin-debug/ bin-release/ ;
sed -i.bak 's/VideoJS.swf/video-js.swf/' bin-release/demo.html ;

echo "Finished." ;
