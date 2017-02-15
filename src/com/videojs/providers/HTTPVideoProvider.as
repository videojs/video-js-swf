package com.videojs.providers{

    import com.videojs.VideoJSModel;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import flash.events.EventDispatcher;
    import flash.events.NetStatusEvent;
    import flash.events.TimerEvent;
    import flash.media.Video;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.net.NetStreamAppendBytesAction;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.utils.getTimer;

    public class HTTPVideoProvider extends EventDispatcher implements IProvider{

        private static var FLV_HEADER = new ByteArray();
        // file marker
        FLV_HEADER.writeByte(0x46); // 'F'
        FLV_HEADER.writeByte(0x4c); // 'L'
        FLV_HEADER.writeByte(0x56); // 'V'

        // version
        FLV_HEADER.writeByte(0x01);

        // flags
        FLV_HEADER.writeByte(0x05); // audio + video

        // data offset, should be 9 for FLV v1
        FLV_HEADER.writeUnsignedInt(3 + 1 + 1 + 4);

        // previous tag size (zero since this is the first tag)
        FLV_HEADER.writeUnsignedInt(0);

        private var _nc:NetConnection;
        private var _ns:NetStream;
        private var _throughputTimer:Timer;
        private var _currentThroughput:int = 0; // in B/sec
        private var _loadStartTimestamp:int;
        private var _loadStarted:Boolean = false;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _pausePending:Boolean = false;
        private var _onmetadadataFired:Boolean = false;

        /**
         * The number of seconds between the logical start of the stream and the current zero
         * playhead position of the NetStream. During normal, file-based playback this value should
         * always be zero. When the NetStream is in data generation mode, seeking during playback
         * resets the zero point of the stream to the seek target. To recover the playhead position
         * in the logical stream, this value can be added to the NetStream reported time.
         *
         * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/net/NetStream.html#play()
         */
        private var _startOffset:Number = 0;
        /**
         * If true, an empty NetStream buffer should be interpreted as the end of the video. This
         * is probably the case because the video data is being fed to the NetStream dynamically
         * through appendBuffer, not for traditional file download video.
         */
        private var _ending:Boolean = false;
        private var _videoReference:Video;

        /**
         * When the player is paused, and a seek is executed, the NetStream.time property will NOT update until the decoder encounters a new time tag,
         * which won't happen until playback is resumed. This wrecks havoc with external scrubber logic, so when the player is paused and a seek is requested,
         * we cache the intended time, and use it IN PLACE OF NetStream's time when the time accessor is hit.
         */
        private var _pausedSeekValue:Number = -1;

        private var _src:Object;
        private var _metadata:Object;
        private var _playbackStarted:Boolean = false;
        private var _isPaused:Boolean = true;
        private var _isBuffering:Boolean = false;
        private var _isSeeking:Boolean = false;
        private var _isLive:Boolean = false;
        private var _canSeekAhead:Boolean = false;
        private var _hasEnded:Boolean = false;
        private var _canPlayThrough:Boolean = false;
        private var _loop:Boolean = false;
        private var _durationOverride:Number;

        private var _model:VideoJSModel;

        public function HTTPVideoProvider(){
            _model = VideoJSModel.getInstance();
            _metadata = {};
            _throughputTimer = new Timer(250, 0);
            _throughputTimer.addEventListener(TimerEvent.TIMER, onThroughputTimerTick);
        }

        public function get loop():Boolean{
            return _loop;
        }

        public function set loop(pLoop:Boolean):void{
            _loop = pLoop;
        }

        public function get time():Number{
            if(_ns != null){
                if(_pausedSeekValue != -1){
                    return _pausedSeekValue;
                }
                else{
                    return _startOffset + _ns.time;
                }
            }
            else{
                return 0;
            }
        }

        public function get duration():Number{
            if(_metadata != null && _metadata.duration != undefined){
                return Number(_metadata.duration);
            } else if( _durationOverride && _durationOverride > 0 ) {
                return _durationOverride;
            }
            else{
                return 0;
            }
        }

        public function set duration(value:Number):void {
            _durationOverride = value;
        }

        public function get readyState():int{
            // if we have metadata and a known duration
            if(_metadata != null && _metadata.duration != undefined){
                // if playback has begun
                if(_playbackStarted){
                    // if the asset can play through without rebuffering
                    if(_canPlayThrough){
                        return 4;
                    }
                    // if we don't know if the asset can play through without buffering
                    else{
                        // if the buffer is full, we assume we can seek a head at least a keyframe
                        if(_ns.bufferLength >= _ns.bufferTime){
                            return 3;
                        }
                        // otherwise, we can't be certain that seeking ahead will work
                        else{
                            return 2;
                        }
                    }
                }
                // if playback has not begun
                else{
                    return 1;
                }
            }
            // if we have no metadata
            else{
                return 0;
            }
        }

        public function get networkState():int{
            if(!_loadStarted){
                return 0;
            }
            else{
                if(_loadCompleted){
                    return 1;
                }
                else if(_loadErrored){
                    return 3;
                }
                else{
                    return 2;
                }
            }
        }

        public function appendBytesAction(action:String):void {
            if(_ns) {
                _ns.appendBytesAction(action);
            }
        }

        public function appendBuffer(bytes:ByteArray):void{
            _ns.appendBytes(bytes);
        }

        public function endOfStream():void{
            _ending = true;
            appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
        }

        public function abort():void{
            // flush the netstream buffers
            _ns.seek(time);
        }

        public function discontinuity():void{
            appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
            FLV_HEADER.position = 0;
            appendBuffer(FLV_HEADER);
        }

        public function get buffered():Array{
            if(_ns) {
                if (_src.path === null) {
                    // data generation mode
                    if (_isSeeking) {
                        return [];
                    }
                    return [[
                        _startOffset + _ns.time - _ns.backBufferLength,
                        _startOffset + _ns.time + _ns.bufferLength
                    ]];
                } else if (duration > 0) {
                    // this calculation is not completely accurate for
                    // many videos (variable bitrate encodings, for
                    // instance) but NetStream.bufferLength does not seem
                    // to return the full amount of buffered time for
                    // progressive download videos.
                    return [[0, (_ns.bytesLoaded / _ns.bytesTotal) * duration]];
                }
            }
            return [];
        }

        public function get bufferedBytesEnd():int{
            if(_loadStarted){
                return _ns.bytesLoaded;
            }
            else{
                return 0;
            }
        }

        public function get bytesLoaded():int{

            return 0;
        }

        public function get bytesTotal():int{

            return 0;
        }

        public function get playing():Boolean{
            return _playbackStarted;
        }

        public function get paused():Boolean{
            return _isPaused;
        }

        public function get ended():Boolean{
            return _hasEnded;
        }

        public function get seeking():Boolean{
            return _isSeeking;
        }

        public function get usesNetStream():Boolean{
            return true;
        }

        public function get metadata():Object{
            return _metadata;
        }

        public function set src(pSrc:Object):void{
            init(pSrc, false);
        }

        public function get srcAsString():String{
            if(_src != null){
                return _src.url;
            }
            return "";
        }

        public function init(pSrc:Object, pAutoplay:Boolean):void{
            _onmetadadataFired = false;
            _src = pSrc;
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
            if (_model.preload == "auto") {
              initNetConnection();
            }
        }

        public function load():void {
            if(!_loadStarted){
                _playbackStarted = false;
                initNetConnection();
            }
        }

        public function play():void{
            // if this is a fresh playback request
            if(!_loadStarted){
                _metadata = {};
                _model.addEventListener(VideoPlaybackEvent.ON_STREAM_READY, function():void{
                    play();
                });
                load();
            } else {
                // if the asset is already loading
                if (_hasEnded) {
                  _hasEnded = false;
                }
                _pausePending = false;
                _ns.resume();
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                if (!_isBuffering) {
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                }
                _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {}));
            }
        }

        public function pause():void{
            var alreadyPaused = _isPaused;
            _ns.pause();
            if(_playbackStarted && !alreadyPaused){
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
                if(_isBuffering){
                    _pausePending = true;
                }
            }
        }

        public function resume():void{
            if(_playbackStarted && _isPaused){
                _ns.resume();
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                if (!_isBuffering) {
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                }
            }
        }

        public function adjustCurrentTime(pValue:Number):void {
            if (_src.path === null) {
                _startOffset = pValue;
            }
        }

        public function seekBySeconds(pTime:Number):void{
            if(_playbackStarted)
            {
                _isSeeking = true;
                _throughputTimer.stop();
                if(_isPaused)
                {
                    _pausedSeekValue = pTime;
                }
            }
            else if(_hasEnded)
            {
                _isSeeking = true;
                _playbackStarted = true;
                _hasEnded = false;
            }

            _isBuffering = true;

            if(_src.path === null)
            {
                _isSeeking = true;
                _startOffset = pTime;
                return;
            }

            _ns.seek(pTime);

        }

        public function seekByPercent(pPercent:Number):void{
            if(_playbackStarted && _metadata.duration != undefined){
                _isSeeking = true;
                if(pPercent < 0){
                    _ns.seek(0);
                }
                else if(pPercent > 1){
                    _throughputTimer.stop();
                    _ns.seek((pPercent / 100) * _metadata.duration);
                }
                else{
                    _throughputTimer.stop();
                    _ns.seek(pPercent * _metadata.duration);

                }
            }
        }

        public function stop():void{
            if(_playbackStarted){
                _ns.close();
                _playbackStarted = false;
                _hasEnded = true;
                _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {}));
                _throughputTimer.stop();
                _throughputTimer.reset();
            }
        }

        public function attachVideo(pVideo:Video):void{
            _videoReference = pVideo;
        }

        public function die():void{
            if(_videoReference)
            {
                // Clears the image currently displayed in the Video object.
                _videoReference.clear();
                _videoReference.attachNetStream(null);
            }

            if( _ns )
            {
                try {
                    _ns.close();
                    _ns = null;
                } catch( err: Error ) {

                }
            }

            if( _nc )
            {
                try {
                    _nc.close();
                    _nc = null;
                } catch( err: Error ) {

                }
            }

            if(_throughputTimer)
            {
                _throughputTimer.reset();
            }
        }

        private function initNetConnection():void{
            // The video element triggers loadstart as soon as the resource selection algorithm selects a source
            // this is somewhat later than that moment but relatively close
            // We check _src.path as it will be null when in data generation mode and we do not
            // want to trigger loadstart in that case (it will be handled by the tech)
            if (!_loadStarted && _src.path != null) {
                _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
            }
            _loadStarted = true;

            if(_nc != null) {
                try {
                    _nc.close();
                } catch( err: Error ) {

                }
                _nc.removeEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
                _nc = null;
            }

            _nc = new NetConnection();
            _nc.client = this;
            _nc.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
            _nc.connect(null);
        }

        private function initNetStream():void{
            if(_ns != null){
                _ns.close();
                _ns.removeEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
                _ns = null;
            }
            _ns = new NetStream(_nc);
            _ns.inBufferSeek = true;
            _ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
            _ns.client = this;
            _ns.bufferTime = .5;
            _ns.play(_src.path);
            _ns.pause();
            _videoReference.attachNetStream(_ns);

            if (_src.path === null) {
              _pausePending = true;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_READY, {ns:_ns}));
        }

        private function calculateThroughput():void{
          // If there is no NetStream, the rest of the calculation is moot.
          if(_ns){
              // if it's finished loading, we can kill the calculations and assume it can play through
              if(_ns.bytesLoaded == _ns.bytesTotal){
                  _canPlayThrough = true;
                  _loadCompleted = true;
                  _throughputTimer.stop();
                  _throughputTimer.reset();
                  _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
              }
              // if it's still loading, but we know its duration, we can check to see if the current transfer rate
              // will sustain uninterrupted playback - this requires the duration to be known, which is currently
              // only accessible via metadata, which isn't parsed until the Flash Player encounters the metadata atom
              // in the file itself, which means that this logic will only work if the asset is playing - preload
              // won't ever cause this logic to run :(
              else if(_ns.bytesTotal > 0 && _metadata != null && _metadata.duration != undefined){
                  _currentThroughput = _ns.bytesLoaded / ((getTimer() - _loadStartTimestamp) / 1000);
                  var __estimatedTimeToLoad:Number = (_ns.bytesTotal - _ns.bytesLoaded) * _currentThroughput;
                  if(__estimatedTimeToLoad <= _metadata.duration){
                      _throughputTimer.stop();
                      _throughputTimer.reset();
                      _canPlayThrough = true;
                      _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
                  }
              }
          }
        }

        private function onNetConnectionStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetConnection.Connect.Success":
                    initNetStream();
                    break;
                case "NetConnection.Connect.Failed":

                    break;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETCONNECTION_STATUS, {info:e.info}));
        }

        private function onNetStreamStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetStream.Pause.Notify":
                    _isPaused = true;
                    break;
                case "NetStream.Unpause.Notify":
                    _isPaused = false;
                    break;
                case "NetStream.Play.Start":
                    _pausedSeekValue = -1;
                    _metadata = null;
                    _canPlayThrough = false;
                    _hasEnded = false;
                    _isBuffering = true;
                    _currentThroughput = 0;
                    _loadStartTimestamp = getTimer();
                    _throughputTimer.reset();
                    _throughputTimer.start();

                    if(_model.autoplay){
                        _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                        _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:e.info}));
                    }
                    break;

                case "NetStream.SeekStart.Notify":
                    if(_src.path === null) {
                        appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
                    }
                    break;

                case "NetStream.Buffer.Full":
                    // NetStream.Seek.Notify fires as soon as the
                    // Netstream's internal buffer has been flushed
                    // but HTML should wait to fire "seeked" until
                    // enough data is available to resume
                    // playback. NetStream.Buffer.Full is the first
                    // moment enough video data is available to begin
                    // playback.
                    // see https://github.com/videojs/video-js-swf/pull/180
                    if (_isSeeking) {
                        _isSeeking = false;
                        _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
                    }

                    _pausedSeekValue = -1;
                    _playbackStarted = true;
                    if(_pausePending){
                        _pausePending = false;
                        _ns.pause();
                        _isPaused = true;
                    } else if (_isBuffering) {
                        _model.broadcastEventExternally(ExternalEventName.ON_START);
                    }
                    _isBuffering = false;
                    break;

                case "NetStream.Buffer.Empty":
                    // should not fire if ended/paused. issue #38
                    if(!_playbackStarted){ return; }

                    // reaching the end of the buffer after endOfStream has been called means we've
                    // hit the end of the video
                    if (_ending) {
                        _ending = false;
                        _playbackStarted = false;
                        _isPaused = true;
                        _hasEnded = true;
                        _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {info:e.info}));
                        _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
                        _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                        break;
                    }

                    _isBuffering = true;
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    break;

                case "NetStream.Play.Stop":
                    if(!_loop){
                        _playbackStarted = false;
                        _hasEnded = true;
                        _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {info:e.info}));
                        _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
                        _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                    }
                    else{
                        _ns.seek(0);
                    }

                    _throughputTimer.stop();
                    _throughputTimer.reset();
                    break;

                case "NetStream.Seek.Notify":
                    _playbackStarted = true;
                    _hasEnded = false;
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_SEEK_COMPLETE, {info:e.info}));
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    _currentThroughput = 0;
                    _loadStartTimestamp = getTimer();
                    _throughputTimer.reset();
                    _throughputTimer.start();
                    break;

                case "NetStream.Play.StreamNotFound":
                    _loadErrored = true;
                    _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
                    break;

                case "NetStream.Video.DimensionChange":
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE, {videoWidth: _videoReference.videoWidth, videoHeight: _videoReference.videoHeight}));
                    if(_model.metadata && _videoReference)
                    {
                        _model.metadata.width = _videoReference.videoWidth;
                        _model.metadata.height = _videoReference.videoHeight;
                    }
                    break;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETSTREAM_STATUS, {info:e.info}));
        }

        private function onThroughputTimerTick(e:TimerEvent):void{
            calculateThroughput();
        }

        public function onMetaData(pMetaData:Object):void{
            _metadata = pMetaData;
            if(pMetaData.duration != undefined){
                _isLive = false;
                _canSeekAhead = true;
                _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _metadata.duration);
            }
            else{
                _isLive = true;
                _canSeekAhead = false;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_META_DATA, {metadata:_metadata}));

            // the first time metadata is encountered, trigger loadedmetadata, canplay, and loadeddata
            if (!_onmetadadataFired) {
                // _src.path will be null when in data generation mode and loadedmetadata will be
                // triggered by the tech
                if (_src.path != null) {
                    _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
                }
                _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
            }

            _onmetadadataFired = true;
        }

        public function onTextData(pTextData:Object):void {
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_TEXT_DATA, {textData:pTextData}));
            _model.broadcastEventExternally(ExternalEventName.ON_TEXT_DATA, pTextData);
        }

        public function onCuePoint(pInfo:Object):void{
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_CUE_POINT, {cuepoint:pInfo}));
        }

        public function onXMPData(pInfo:Object):void{
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_XMP_DATA, {cuepoint:pInfo}));
        }

        public function onPlayStatus(e:Object):void{

        }
    }
}
