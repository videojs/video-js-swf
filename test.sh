#!/bin/bash

# See README.md for instructions

flex_sdk=$1

if [ -z "$flex_sdk" ]
then
  echo "Usage: test.sh flex_sdk_dir"
  exit 1
fi
if [ ! -d "$flex_sdk" ]
then
  echo "Flex SDK not found at $flex_sdk"
  exit 1
fi

echo "Compiling bin-debug/test-video-js.swf..."
$flex_sdk/bin/mxmlc ./src/AirTestRunner.mxml -o ./bin-debug/test-video-js.swf -use-network=false -static-link-runtime-shared-libraries=true -library-path+=libs

echo "Running test-video-js.swf..."
open ./bin-debug/test-video-js.swf
echo "Open command was run.  If you don't see a SWF running, you're"
echo "probably not on a Mac.  Try to run this in a browser:"
echo `pwd`"./bin-debug/test-video-js.swf"

echo "Running tests/test.html..."
open ./tests/test.html
echo "Again, if you don't see the page above running, you'll need"
echo "to open it manually in a browser:"
echo `pwd`"./tests/test.html"

