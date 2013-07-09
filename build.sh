#!/bin/bash
# Compiles the plugin using the free Flex SDK on Linux/Mac:
# http://opensource.adobe.com/wiki/display/flexsdk/Flex+SDK

# From a shell prompt: sh build.sh

flex_sdk=$1
if [ -z "$flex_sdk" ]
then
  flex_sdk="$FLEX_SDK"
  if [ -z "$flex_sdk" ]
  then
    echo "build.sh flex_sdk_dir"
    exit 1;
  fi
fi

echo "Compiling video-js.swf..."

# TODO: fix starting comment
# copy video-js.swf to video.js 

$flex_sdk/bin/mxmlc ./src/VideoJS.as -o ./bin-release/video-js.swf -target-player=10.3
