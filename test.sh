#!/bin/bash

# See README.md for instructions

flex_sdk=$1

if [ ! -d "$flex_sdk" ]
then
  echo "Flex SDK not found at $flex_sdk"
  exit 1
fi

echo "Compiling test-video-js.swf..."

$flex_sdk/bin/mxmlc ./src/AirTestRunner.mxml -o ./bin-debug/test-video-js.swf -use-network=false -static-link-runtime-shared-libraries=true -library-path+=libs
open ./bin-debug/test-video-js.swf
echo "SWF compiled to bin-debug/test-video-js.swf."
