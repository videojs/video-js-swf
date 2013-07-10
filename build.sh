#!/bin/bash
# Compiles the plugin using the free Flex SDK on Linux/Mac:
# http://opensource.adobe.com/wiki/display/flexsdk/Flex+SDK

# From a shell prompt: sh build.sh

echo "Compiling video-js.swf..."

# Make sure the path to mxmlc is correct!
/Developer/SDKs/flex_sdk_4/bin/mxmlc ./src/VideoJS.as -o ./bin-release/video-js.swf -use-network=false -static-link-runtime-shared-libraries=true
