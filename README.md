The light-weight Flash video player that makes Flash work like HTML5 video. This allows player skins, plugins, and other features to work with both HTML5 and Flash

This project doesn't need to be used if you simply want to use the Flash video player.  Head back to the main Video.js project if that's all you need, as the compiled SWF is checked in there.

Installation
============

1. Go through the Getting started section for [Video.js](https://github.com/videojs/video.js/blob/master/CONTRIBUTING.md) 

2. Install [Apache Flex](http://flex.apache.org/installer.html).  There's no need to install any of the optional items.

3. In the base directory of video-js-swf, you'll see a setup.sh script.  Make sure to include the path to Video.js and Flex SDK as arguments to the script.

   ```bash
   ./setup.sh [video_js_dir] [flex_sdk_dir]
   ```
   This script will do the following:
   - Create a new directory in your Flex SDK for playerglobal10_3.swc, and download this file.
   - Set up the bin-debug and bin-release directories.
.
4. Install a simple HTTP server for simpler testing.

    ```bash
    npm -g install simple-http-server
    ```
    
5. Build video-js.swf using build.sh.  Make sure to include the path to the Flex SDK as an argument to the script.

    ```bash
    ./build.sh [flex_sdk_dir]
    ```

   This script will do the following:
   - Compile the source into bin-release using the release compiler settings.
   - Copy the SWF into [video.js]/src/swf/video-js.swf
    
7. Start running the simple HTTP server from the command-line.

    ```bash
    nserver
    ```
    
Now you can see the demo working with your newly-built code: [http://localhost:8000/bin-release/demo.html]

You can keep using build.sh to rebuild the Flash code.

Using with Your IDE
============

The bin-debug directory is set up for usage with your IDE

If you don't want to keep using build.sh to build the code, the bin-debug directory is set up for use with your IDE.  It is similar to the bin-release directory, except that the SWF name is expected to be VideoJS.swf.  This works better with some IDEs that expect the SWF name to be the same as the main class name.

You can also use the given .actionscriptProperties with Flash Builder.  It is set up to use bin-debug and generally ready to use.  When you want to run the project, set the output URL to http://localhost:8000/bin-release/demo.html.  As long as nserver is running, you should get the latest code you compile there.

