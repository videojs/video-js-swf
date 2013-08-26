#!/bin/bash

# See README.md for instructions

pwd=`pwd`
flex_sdk=/Applications/Flex

# use command-line parameters if the default location
# isn't available
if [ ! -d "$flex_sdk" ]
then
  flex_sdk=$1
fi

# if we needed a command-line parameter and didn't get one,
# complain about it
if [ -z "$flex_sdk" ]
then
  echo "Usage: test.sh flex_sdk_dir"
  exit 1
fi

# complain about the incorrect directory passed in
if [ ! -d "$flex_sdk" ]
then
  echo "Flex SDK not found at $flex_sdk"
  exit 1
fi

# and now we can get started, echoing out what we're doing

echo "Compiling bin-debug/test-video-js.swf..."
$flex_sdk/bin/mxmlc ./src/AirTestRunner.mxml -o ./bin-debug/test-video-js.swf -use-network=false -static-link-runtime-shared-libraries=true -library-path+=libs

forever stop http/server.js 2> /dev/null
forever start --minUptime=1000 --spinSleepTime=1000 http/server.js

echo "Running test-video-js.swf..."
open bin-debug/test-video-js.swf
echo "Open command was run.  If you don't see a SWF running, you're"
echo "probably not on a Mac.  Try to run this:"
echo "$pwd/bin-debug/test-video-js.swf"

echo "Running tests/test.html..."
open http://localhost:8000/tests/test.html
echo "Again, if you don't see the page above running, you'll need"
echo "to open it manually in a browser:"
echo "http://localhost:8000/tests/test.html"
