The light-weight Flash video player that makes Flash work like HTML5 video. This allows player skins, plugins, and other features to work with both HTML5 and Flash

TODO: note that this project isn't needed to use the SWF.  Just use video.js for that.

Installation
============

1. Go through the Getting started section for  [Video.js](https://github.com/videojs/video.js/blob/master/CONTRIBUTING.md) 

2. Install [Apache Flex](http://flex.apache.org/installer.html).  There's no need to install any of the optional items.

3. One additional item needs to be downloaded for the Flex SDK.  Subsitute in the location of your Flex SDK directory in both lines below.

    mkdir [flex_sdk_dir]/frameworks/libs/player/10.3/
    curl -o [flex_sdk_dir]/frameworks/libs/player/10.3/playerglobal.swc http://fpdownload.macromedia.com/get/flashplayer/updaters/10/playerglobal10_3.swc

4. Install a simple HTTP server for simpler testing.

    npm -g install simple-http-server

5. Set up the local testing directories, bin-release and bin-debug, with setup.sh.  Make sure to include the path to Video.js as the first argument to the script.

    ./setup.sh [video_js_dir]

6. Build video-js.swf using build.sh.  Make sure to include the path to the Flex SDK as the first argument to the script.

    ./build.sh [flex_sdk_dir]

7. Start running the simple HTTP server from the command-line

    nserver

And then you can see the demo working: [http://localhost:8000/bin-release/demo.html]

Using with Your IDE
============

TODO: make a note about .actionScriptProperties checked in and generally ready to use with bin-debug.  Need to point the output URL to launch to http://localhost:8000/bin-release/demo.html and have nserver running
