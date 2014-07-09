package com.videojs.providers{

  import flash.media.Video;
  import flash.utils.ByteArray;
  import flash.net.NetStream;
  import flash.events.Event;

  import com.videojs.VideoJSModel;
  import com.videojs.events.VideoPlaybackEvent;
  import com.videojs.structs.ExternalErrorEventName;
  import com.videojs.structs.ExternalEventName;
  import com.videojs.structs.ReadyState;
  import com.videojs.structs.NetworkState;

  import org.mangui.hls.HLS;
  import org.mangui.hls.HLSEvent;
  import org.mangui.hls.HLSSettings;
  import org.mangui.hls.HLSPlayStates;
  import org.mangui.hls.utils.Log;

  public class HLSProvider implements IProvider {

        private var _loop:Boolean = false;
        private var _looping:Boolean = false;
        private var _hls:HLS;
        private var _src:Object;
        private var _model:VideoJSModel;
        private var _videoReference:Video;
        private var _metadata:Object;
        private var _mediaWidth:Number;
        private var _mediaHeight:Number;

        private var _hlsState:String = HLSPlayStates.IDLE;
        private var _networkState:Number = NetworkState.NETWORK_EMPTY;
        private var _readyState:Number = ReadyState.HAVE_NOTHING;
        private var _position:Number = 0;
        private var _duration:Number = 0;
        private var _isAutoPlay:Boolean = false;
        private var _isManifestLoaded:Boolean = false;
        private var _isPlaying:Boolean = false;
        private var _isSeeking:Boolean = false;
        private var _isPaused:Boolean = true;
        private var _isEnded:Boolean = false;

        private var _bytesLoaded:Number = 0;
        private var _bytesTotal:Number = 0;
        private var _bufferedTime:Number = 0;

        public function HLSProvider() {
          Log.info("flashls 0.1.0");
          //HLSSettings.logDebug = true;
          _hls = new HLS();
          HLSSettings.flushLiveURLCache=true;
          _model = VideoJSModel.getInstance();
          _metadata = {};
          _hls.addEventListener(HLSEvent.PLAYBACK_COMPLETE,_completeHandler);
          _hls.addEventListener(HLSEvent.ERROR,_errorHandler);
          _hls.addEventListener(HLSEvent.MANIFEST_LOADED,_manifestHandler);
          _hls.addEventListener(HLSEvent.MEDIA_TIME,_mediaTimeHandler);
          _hls.addEventListener(HLSEvent.PLAYBACK_STATE,_stateHandler);
        }

        private function _completeHandler(event:HLSEvent):void {
          if(!_loop){
            _isEnded = true;
            _isPaused = true;
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {}));
            _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
          } else {
            _looping = true;
            load();
          }
        };

        private function _errorHandler(event:HLSEvent):void {
          Log.debug("error!!!!:"+ event.error.msg);
          _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
          _networkState = NetworkState.NETWORK_NO_SOURCE;
          _readyState = ReadyState.HAVE_NOTHING;
          stop();
        };

        private function _manifestHandler(event:HLSEvent):void {
          _isManifestLoaded = true;
          _networkState = NetworkState.NETWORK_IDLE;
          _readyState = ReadyState.HAVE_METADATA;
          _duration = event.levels[0].duration;
          _metadata.width = event.levels[0].width;
          _metadata.height = event.levels[0].height;
          if(_isAutoPlay || _looping) {
            _looping = false;
            play();
          }
          _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
          _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _duration);
          _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_META_DATA, {metadata:_metadata}));
          _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
        };

        private function _mediaTimeHandler(event:HLSEvent):void {
          _position = event.mediatime.position;
          _bufferedTime = event.mediatime.buffer+event.mediatime.position;

          if(event.mediatime.duration != _duration) {
            _duration = event.mediatime.duration;
            _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _duration);
          }
        };

        private function _stateHandler(event:HLSEvent):void {
          _hlsState = event.state;
          Log.debug("state:"+ _hlsState);
          switch(event.state) {
              case HLSPlayStates.IDLE:
                _networkState = NetworkState.NETWORK_IDLE;
                _readyState = ReadyState.HAVE_METADATA;
                break;
              case HLSPlayStates.PLAYING_BUFFERING:
                _isPlaying = true;
                _isPaused = false;
                _isEnded = false;
                _isSeeking = false;
                _networkState = NetworkState.NETWORK_LOADING;
                _readyState = ReadyState.HAVE_CURRENT_DATA;
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                break;
              case HLSPlayStates.PLAYING:
                _isPlaying = true;
                _isPaused = false;
                _isEnded = false;
                _isSeeking = false;
                _networkState = NetworkState.NETWORK_LOADING;
                _readyState = ReadyState.HAVE_ENOUGH_DATA;
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:{}}));
                break;
              case HLSPlayStates.PAUSED:
                _isPaused = true;
                _isEnded = false;
                _isSeeking = false;
                _networkState = NetworkState.NETWORK_LOADING;
                _readyState = ReadyState.HAVE_ENOUGH_DATA;
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                break;
              case HLSPlayStates.PAUSED_BUFFERING:
                _isPaused = true;
                _isEnded = false;
                _networkState = NetworkState.NETWORK_LOADING;
                _readyState = ReadyState.HAVE_CURRENT_DATA;
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                break;
          }
        };

        private function _onFrame(event:Event):void
        {
          var newWidth:Number = _videoReference.videoWidth;
          var newHeight:Number =  _videoReference.videoHeight;
          if  (newWidth != 0 && 
               newHeight != 0 && 
               newWidth != _mediaWidth && 
               newHeight != _mediaHeight)
          {
            _mediaWidth = newWidth;
            _mediaHeight = newHeight;
            Log.info("video size changed to ("+newWidth+","+newHeight+")");
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE, {videoWidth: newWidth, videoHeight: newHeight}));
          }
        }

        public function get loop():Boolean{
            return _loop;
        }

        public function set loop(pLoop:Boolean):void{
            _loop = pLoop;
        }

        /**
         * Should return a value that indicates the current playhead position, in seconds.
         */
        public function get time():Number {
          return _position;
        }

        /**
         * Should return a value that indicates the current asset's duration, in seconds.
         */
        public function get duration():Number  {
          return _duration;
        }

        /**
         * Appends the segment data in a ByteArray to the source buffer.
         * @param  bytes the ByteArray of data to append.
         */
        public function appendBuffer(bytes:ByteArray):void {
          throw "HLSProvider does not support appendBuffer";
        }

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's readyState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        public function get readyState():int {
          return _readyState;
        }

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's networkState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        public function get networkState():int {
          return _networkState;
        }

        /**
         * Should return the amount of media that has been buffered, in seconds, or 0 if
         * this value is unknown or unable to be determined (due to lack of duration data, etc)
         */
        public function get buffered():Number {
          return _bufferedTime;
        }

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bufferedBytesEnd():int {
          return 0;
        }

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bytesLoaded():int {
          return 0;
        }

        /**
         * Should return the total bytes of the current asset, or 0 if this value is
         * unknown or unable to be determined (due to streaming, bitrate switching, etc)
         */
        public function get bytesTotal():int{
          return 0;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is playing.
         */
        public function get playing():Boolean {
          Log.debug("HLSProvider.playing:"+_isPlaying);
          return _isPlaying;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is paused.
         */
        public function get paused():Boolean {
          Log.debug("HLSProvider.paused:"+_isPaused);
          return _isPaused;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset has ended. This value should default to false, and be reset with every seek request within
         * the same asset.
         */
        public function get ended():Boolean {
          Log.debug("HLSProvider.ended:"+_isEnded);
          return _isEnded;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is in the process of seeking to a new time point.
         */
        public function get seeking():Boolean {
          return _isSeeking;
        }

        /**
         * Should return a boolean value that indicates whether or not this provider uses the NetStream class.
         */
        public function get usesNetStream():Boolean {
          return true;
        }

        /**
         * Should return an object that contains metadata properties, or an empty object if metadata doesn't exist.
         */
        public function get metadata():Object {
          Log.debug("HLSProvider.metadata");
          return _metadata;
        }

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function get srcAsString():String{
            if(_src != null){
                return _src.m3u8;
            }
            return "";
        }

        /**
         * Should contain an object that enables the provider to play whatever media it's designed to play.
         * Compare the difference in implementation between HTTPVideoProvider and RTMPVideoProvider to see
         * one example of how this object can be used.
         */
        public function set src(pSrc:Object):void {
          Log.debug("HLSProvider.src");
          _src = pSrc;
        }

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function init(pSrc:Object, pAutoplay:Boolean):void {
          _src = pSrc;
          _isAutoPlay = pAutoplay;
          load();
          return;
        }

        /**
         * Called when the media asset should be preloaded, but not played.
         */
        public function load():void {
          if(_src !=null) {
            Log.debug("HLSProvider.load:"+ _src.m3u8);
            _isManifestLoaded = false;
            _position = 0;
            _duration = 0;
            _bufferedTime = 0;
            _hls.load(_src.m3u8);
          }
        }

        /**
         * Called when the media asset should be played immediately.
         */
        public function play():void {
          Log.debug("HLSProvider.play.state:" + _hlsState);
          if(_isManifestLoaded) {
            switch(_hlsState) {
              case HLSPlayStates.IDLE:
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                _hls.stream.play();
                break;
              case HLSPlayStates.PAUSED:
              case HLSPlayStates.PAUSED_BUFFERING:
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                _hls.stream.resume();
                break;
              default:
                break;
            }
          }
        }

        /**
         * Called when the media asset should be paused.
         */
        public function pause():void {
          Log.debug("HLSProvider.pause");
          _hls.stream.pause();
          _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
        }

        /**
         * Called when the media asset should be resumed from a paused state.
         */
        public function resume():void {
          Log.debug("HLSProvider.resume");
          _hls.stream.resume();
          _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
        }

        /**
         * Called when the media asset needs to seek to a new time point.
         */
        public function seekBySeconds(pTime:Number):void {
          Log.debug("HLSProvider.seekBySeconds");
          if(_isManifestLoaded) {
            _isSeeking = true;
            _position = pTime;
            _bufferedTime = _position;
            _hls.stream.seek(pTime);
          }
        }

        /**
         * Called when the media asset needs to seek to a percentage of its total duration.
         */
        public function seekByPercent(pPercent:Number):void {
          Log.debug("HLSProvider.seekByPercent");
          if(_isManifestLoaded) {
            _isSeeking = true;
            _position = pPercent*_duration;
            _bufferedTime = _position;
            _hls.stream.seek(pPercent*_duration);
          }
        }

        /**
         * Called when the media asset needs to stop.
         */
        public function stop():void {
          Log.debug("HLSProvider.stop");
          _hls.stream.close();
          _bufferedTime = 0;
          _duration = 0;
          _position = 0;
          _networkState = NetworkState.NETWORK_EMPTY;
          _readyState = ReadyState.HAVE_NOTHING;
          _isManifestLoaded = false;
        }

        /**
         * For providers that employ an instance of NetStream, this method is used to connect that NetStream
         * with an external Video instance without exposing it.
         */
        public function attachVideo(pVideo:Video):void {
          _videoReference = pVideo;
          _videoReference.attachNetStream(_hls.stream);
          _videoReference.addEventListener(Event.ENTER_FRAME, _onFrame);
          _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_READY, {ns:_hls.stream as NetStream}));
          return;
        }

        /**
         * Called when the provider is about to be disposed of.
         */
        public function die():void {
          Log.debug("HLSProvider.die");
          stop();

          if(_videoReference) {
            _videoReference.clear();
          }
        }
    }
}