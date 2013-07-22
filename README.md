The light-weight Flash video player that makes Flash work like HTML5 video. This allows player skins, plugins, and other features to work with both HTML5 and Flash

This project doesn't need to be used if you simply want to use the Flash video player.  Head back to the main Video.js project if that's all you need, as the compiled SWF is checked in there.

Installation
============

1. Go through the Getting started section for [Video.js](https://github.com/videojs/video.js/blob/master/CONTRIBUTING.md).  Most importantly, you will need have already built Video.js successfully before building video-js-swf.

2. Install [Apache Flex](http://flex.apache.org/installer.html).  There's no need to install any of the optional items.

3. You'll need the Flash Player 10.3 library to compile.  Run the commands below to get them installed.

    ```bash
    export FLEX_HOME=[flex_home]
    mkdir -p "$FLEX_HOME/frameworks/libs/player/10.3"
    curl --silent -o "$FLEX_HOME/frameworks/libs/player/10.3/playerglobal.swc" "http://fpdownload.macromedia.com/get/flashplayer/updaters/10/playerglobal10_3.swc"
   ```

4. Install a simple HTTP server for simpler testing.

    ```bash
    npm -g install simple-http-server
    ```
    
5. Build the SWF using build.sh.  Make sure to include the paths to Video.js and the Flex SDK as arguments to the script.

    ```bash
    ./build.sh [video_js_dir] [flex_sdk_dir]
    ```

7. Start running the simple HTTP server from the command-line in the video-js-swf root directory.

    ```bash
    nserver
    ```
    
8. Open your browser at [http://localhost:8000/bin-debug/index.html] to see a video play.  You can keep using build.sh to rebuild the Flash code.

Using with Your IDE
============

If you don't want to keep using build.sh to build the code, you don't have to.  The bin-debug directory is set up for usage with your IDE.

You can use the given .actionscriptProperties with Flash Builder.  It is set up to use bin-debug and generally ready to use.  When you want to run the project, set the output URL to http://localhost:8000/bin-debug/index.html.  As long as nserver is running, you should get the latest code you compile there.

Running Unit and Integration Tests
===========

For unit tests, this project uses FlexUnit.  FlexUnit is built into [Adobe FlashBuilder](ihttp://www.adobe.com/products/flash-builder.html) and is also available on [GitHub](https://github.com/flexunit/flexunit) if you are only interested in the binaries.

The unit tests can be found in [project root]/src/com/videojs/test/

For integration tests, this project uses [qunit](http://qunitjs.com/).

The integration tests can be found in [project root]/test

In order to run all of the tests, run test.sh.

    ```bash
    ./test.sh
    ```

A copy of the SWF produced for the unit tests will be compiled into the bin-debug folder.  Both the unit and integration tests will attempt to run with the 'open' command, or an instruction will be given on how to run them manually.
