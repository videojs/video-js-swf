The light-weight Flash video player that makes Flash work like HTML5 video. This allows player skins, plugins, and other features to work with both HTML5 and Flash

TODO: note that this project isn't needed to use the SWF.  Just use video.js for that.

Installation
============

1. Go through the Getting started section for  [Video.js](https://github.com/videojs/video.js/blob/master/CONTRIBUTING.md) 

2. Install [Apache Flex](http://flex.apache.org/installer.html).  There's no need to install any of the optional items.

3. Go into video-js-swf and run the setup.sh script. Supply your video.js and Flex SDK directories as the first and second arguments:

   ```bash
   ./setup.sh [video_js_dir] [flex_sdk_dir]
   ```
   This script will do the following:
   - Create a new directory in your Flex SDK for the playerglobal10_3.swc, and download it
   - Create bin-debug and bin-release directories
.
4. Install a simple HTTP server for simpler testing.

    ```bash
    npm -g install simple-http-server
    ```
    
5. Set up the local testing directories, bin-release and bin-debug, with setup.sh.  Make sure to include the path to Video.js as the first argument to the script.

    ```bash
    ./setup.sh [video_js_dir]
    ```
    
6. Build video-js.swf using build.sh.  Make sure to include the path to the Flex SDK as the first argument to the script.

    ```bash
    ./build.sh [flex_sdk_dir]
    ```
    
7. Start running the simple HTTP server from the command-line

    ```bash
    nserver
    ```
    
And then you can see the demo working: [http://localhost:8000/bin-release/demo.html]

Using with Your IDE
============

TODO: make a note about .actionScriptProperties checked in and generally ready to use with bin-debug.  Need to point the output URL to launch to http://localhost:8000/bin-release/demo.html and have nserver running
