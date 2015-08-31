CHANGELOG
=========

## HEAD (Unreleased)
_(none)_

--------------------

## 4.7.5 (2015-08-31)
* @dmlap remove poster emulation ([view](https://github.com/videojs/video-js-swf/pull/183))

## 4.7.4 (2015-08-11)
* revert [#173](https://github.com/videojs/video-js-swf/pull/173)

## 4.7.3 (2015-08-10)
* @bc-bbay fix seeking after the video has ended ([view](https://github.com/videojs/video-js-swf/pull/175))
* @imbcmdth don't trigger loadstart or loadedmetadata in data generation mode ([view](https://github.com/videojs/video-js-swf/pull/173))

## 4.7.2 (2015-06-30)
* Fixed an issue where an image from previous video could flash briefly while a new video is loaded ([view](https://github.com/videojs/video-js-swf/pull/167))

## 4.7.1 (2015-06-23)
* Fixed an issue where playback required two clisk to start when preload was not auto
* @qpSHiNqp fix issue that would cause incorrect aspect ratios for some videos ([view](https://github.com/videojs/video-js-swf/pull/165))

## 4.7.0 (2015-05-19)
* @bc-bbay the preload attribute should be a string, not a boolean ([view](https://github.com/videojs/video-js-swf/pull/160))
* @Wellming fix manual tests ([view](https://github.com/videojs/video-js-swf/pull/154))

## 4.6.1 (2015-04-22)
* @bclwhitaker append END_SEQUENCE properly in data generation mode ([view](https://github.com/videojs/video-js-swf/pull/152))

## 4.6.0 (2015-04-16)
* Add vjs_discontinuity ([view](https://github.com/videojs/video-js-swf/pull/150))
* Don't call resume() on NetstreamPlayStart ([view](https://github.com/videojs/video-js-swf/pull/147))

## 4.5.4 (2015-03-17)
* Improved handling of the paused state, and the loadstart and canplay events ([view](https://github.com/videojs/video-js-swf/pull/139))
* Fixed a potential XSS issue with the swf event callbacks ([view](https://github.com/videojs/video-js-swf/pull/143))
* Prevented pause from firing after eneded ([view](https://github.com/videojs/video-js-swf/pull/144))

## 4.5.3 (2015-01-22)
* Paused should be true before a source has been set by default

## 4.5.2 (2014-12-04)
* Fixed an issue where Flash would crash when switching sources quickly ([view](https://github.com/videojs/video-js-swf/pull/131))

## 4.5.1 (2014-10-15)
* Fixed an issue where changing the source immediately after seeking could cause an error ([view](https://github.com/videojs/video-js-swf/pull/125))
* Added sanitation for all data that might be passed through the external interface ([view](https://github.com/videojs/video-js-swf/pull/127))

## 4.5.0 (2014-09-29)
* Buffering and playback event fixes ([view](https://github.com/videojs/video-js-swf/pull/122))

## 4.4.5 (2014-09-25)
* Fixed sanitation of URLs to special case blob URLs ([view](https://github.com/videojs/video-js-swf/pull/121))

## 4.4.4 (2014-09-22)
* Added sanitizing of the src param ([view](https://github.com/videojs/video-js-swf/pull/120))

## 4.4.3 (2014-08-14)
* Rebuild with Flash target-player 10.3 and swf-version 12. ([view](https://github.com/videojs/video-js-swf/issues/113))

## 4.4.2 (2014-07-11)
* Fixed networkState reporting to be more accurate after loadstart ([view](https://github.com/videojs/video-js-swf/pull/106))

## 4.4.1 (2014-06-11)
* Ignore unnecessary files from npm packaging ([view](https://github.com/videojs/video-js-swf/pull/87))
* Fixed bug triggering `playing` ([view](https://github.com/videojs/video-js-swf/pull/90))
* Fixed bug with the timing of `loadstart` ([view](https://github.com/videojs/video-js-swf/pull/93))
* Added support for clearing the NetStream while in Data Generation Mode ([view](https://github.com/videojs/video-js-swf/pull/93))
* Fixed silent exception when opening MediaSources ([view](https://github.com/videojs/video-js-swf/pull/97))

## 4.4.0 (2014-02-18)
* Added changelog
* Added support for using NetStream in Data Generation Mode ([view](https://github.com/videojs/video-js-swf/pull/80))
* Extended base support for external appendData for integration with HLS / Media Source plugins ([view](https://github.com/videojs/video-js-swf/pull/80))
* Fixed bug with viewport sizing on videos which don't present meta data ([view](https://github.com/videojs/video-js-swf/pull/80))
* Fixed bugs with buffered and duration reporting on non-linear streams ([view](https://github.com/videojs/video-js-swf/pull/80))
* Added refined seeking for use on non-linear streams ([view](https://github.com/videojs/video-js-swf/pull/80))
* Extended endOfStream for use with Media Sources API ([view](https://github.com/videojs/video-js-swf/pull/80))
