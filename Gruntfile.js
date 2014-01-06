module.exports = function (grunt) {

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    connect: {
      dev: {
        port: 8000,
        base: 'build/files'
      }
    },
    mxmlc: {
      options: {
        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_16.html
        metadata: {
          // `-title "Adobe Flex Application"`
          title: 'VideoJS SWF',
          // `-description "http://www.adobe.com/flex"`
          description: 'http://www.videojs.com',
          // `-publisher "The Publisher"`
          publisher: 'Brightcove, Inc.',
          // `-creator "The Author"`
          creator: 'Brightcove, Inc.',
          // `-language=EN`
          // `-language+=klingon`
          language: 'EN',
          // `-localized-title "The Color" en-us -localized-title "The Colour" en-ca`
          localizedTitle: null,
          // `-localized-description "Standardized Color" en-us -localized-description "Standardised Colour" en-ca`
          localizedDescription: null,
          // `-contributor "Contributor #1" -contributor "Contributor #2"`
          contributor: null,
          // `-date "Mar 10, 2013"`
          date: null
        },

        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_18.html
        application: {
          // `-default-size 240 240`
          layoutSize: {
            width: 640,
            height: 360
          },
          // `-default-frame-rate=24`
          frameRate: 30,
          // `-default-background-color=0x869CA7`
          backgroundColor: 0x000000,
          // `-default-script-limits 1000 60`
          scriptLimits: {
            maxRecursionDepth: 1000,
            maxExecutionTime: 60
          }
        },

        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_19.html
        // `-library-path+=libraryPath1 -library-path+=libraryPath2`
        libraries: ['libs/*.*'],
        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_14.html
        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_17.html
        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_20.html
        // http://livedocs.adobe.com/flex/3/html/help.html?content=compilers_21.html
        compiler: {
          // `-accessible=false`
          'accessible': false,
          // `-actionscript-file-encoding=UTF-8`
          'actionscriptFileEncoding': null,
          // `-allow-source-path-overlap=false`
          'allowSourcePathOverlap': false,
          // `-as3=true`
          'as3': true,
          // `-benchmark=true`
          'benchmark': true,
          // `-context-root context-path`
          'contextRoot': null,
          // `-debug=false`
          'debug': false,
          // `-defaults-css-files filePath1 ...`
          'defaultsCssFiles': [],
          // `-defaults-css-url http://example.com/main.css`
          'defaultsCssUrl': null,
          // `-define=CONFIG::debugging,true -define=CONFIG::release,false`
          // `-define+=CONFIG::bool2,false -define+=CONFIG::and1,"CONFIG::bool2 && false"
          // `-define+=NAMES::Company,"'Adobe Systems'"`
          'defines': {},
          // `-es=true -as3=false`
          'es': false,
          // `-externs className1 ...`
          'externs': [],
          // `-external-library-path+=pathElement`
          'externalLibraries': [],
          'fonts': {
            // `-fonts.advanced-anti-aliasing=false`
            advancedAntiAliasing: false,
            // `-fonts.languages.language-range "Alpha and Plus" "U+0041-U+007F,U+002B"`
            // USAGE:
            // ```
            // languages: [{
            //   lang: 'Alpha and Plus',
            //   range: ['U+0041-U+007F', 'U+002B']
            // }]
            // ```
            languages: [],
            // `-fonts.local-fonts-snapsnot filePath`
            localFontsSnapshot: null,
            // `-fonts.managers flash.fonts.JREFontManager flash.fonts.BatikFontManager flash.fonts.AFEFontManager`
            // NOTE: FontManager preference is in REVERSE order (prefers LAST array item).
            //       For more info, see http://livedocs.adobe.com/flex/3/html/help.html?content=fonts_06.html
            managers: []
          },
          // `-incremental=false`
          'incremental': false
        }
      },
      videojs_swf: {
        files: {
          'build/files/swf/VideoJS.swf': ['src/VideoJS.as']
        }
      }
    }

  });

  grunt.loadNpmTasks('grunt-connect');

  grunt.registerMultiTask('mxmlc', 'Compiling SWF', function () {
    // Merge task-specific and/or target-specific options with these defaults.
    var childProcess = require('child_process');
    var flexSdk = require('flex-sdk');
    var async = require('async');

    var
      options = this.options,
      done = this.async(),
      maxConcurrency = 1,
      q,
      workerFn;

    workerFn = function(f, callback) {
      // Concat specified files.
      var srcList = f.src.filter(function(filepath) {
        // Warn on and remove invalid source files (if nonull was set).
        if (!grunt.file.exists(filepath)) {
          grunt.log.error('Source file "' + filepath + '" not found.');
          return false;
        }
        else {
          return true;
        }
      });

      var cmdLineOpts = [];

      if (f.dest) {
        cmdLineOpts.push('-output');
        cmdLineOpts.push(f.dest);
      }
      cmdLineOpts.push('--');
      cmdLineOpts.push.apply(cmdLineOpts, srcList);

      grunt.verbose.writeln('mxmlc path: ' + flexSdk.bin.mxmlc);
      grunt.verbose.writeln('options: ' + JSON.stringify(cmdLineOpts));

      // Compile!
      childProcess.execFile(flexSdk.bin.mxmlc, cmdLineOpts, function(err, stdout, stderr) {
        if (!err) {
          grunt.log.writeln('File "' + f.dest + '" created.');
        }
        else {
          grunt.log.error(err.toString());
          grunt.verbose.writeln('stdout: ' + stdout);
          grunt.verbose.writeln('stderr: ' + stderr);

          if (options.force === true) {
            grunt.log.warn('Should have failed but will continue because this task had the `force` option set to `true`.');
          }
          else {
            grunt.fail.warn('FAILED');
          }

        }
        callback(err);
      });
    };

    q = async.queue(workerFn, maxConcurrency);
    q.drain = done;
    q.push(this.files);
  });

  grunt.registerTask('dist', 'Creating distribution', function () {
    grunt.task.run('mxmlc');
    grunt.file.copy('build/files/swf/VideoJS.swf', 'dist/VideoJS.swf');
  });

};
