package com.videojs.providers{

    import com.videojs.VideoJSModel;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.structs.PlaybackType;

    import flash.events.EventDispatcher;
    import flash.events.NetStatusEvent;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.media.Video;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.utils.getTimer;

    public class RTMPVideoProvider extends EventDispatcher implements IProvider{

        private var _nc:NetConnection;
        private var _ns:NetStream;
        private var _rtmpRetryTimer:Timer;
        private var _ncRTMPRetryThreshold:int = 3;
        private var _ncRTMPCurrentRetry:int = 0;
        private var _throughputTimer:Timer;
        private var _currentThroughput:int = 0; // in B/sec
        private var _loadStartTimestamp:int;
        private var _loadStarted:Boolean = false;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _pauseOnStart:Boolean = false;
        private var _pausePending:Boolean = false;
        private var _videoReference:Video;

        private var _src:Object;
        private var _metadata:Object;
        private var _hasDuration:Boolean = false;
        private var _isPlaying:Boolean = false;
        private var _isPaused:Boolean = true;
        private var _isBuffering:Boolean = false;
        private var _isSeeking:Boolean = false;
        private var _isLive:Boolean = false;
        private var _canSeekAhead:Boolean = false;
        private var _hasEnded:Boolean = false;
        private var _reportEnded:Boolean = false;
        private var _canPlayThrough:Boolean = false;
        private var _loop:Boolean = false;

        private var _model:VideoJSModel;

        public function RTMPVideoProvider(){
            _model = VideoJSModel.getInstance();
            _metadata = {};
            _rtmpRetryTimer = new Timer(25, 1);
            _rtmpRetryTimer.addEventListener(TimerEvent.TIMER, onRTMPRetryTimerTick);
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
                return _ns.time;
            }
            else{
                return 0;
            }
        }

        public function get duration():Number{
            if(_metadata != null && _metadata.duration != undefined){
                return Number(_metadata.duration);
            }
            else{
                return 0;
            }
        }

        public function get readyState():int{
            // if we have metadata and a known duration
            if(_metadata != null && _metadata.duration != undefined){
                // if playback has begun
                if(_isPlaying){
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

        public function appendBuffer(bytes:ByteArray):void{
            throw "RTMPVideoProvider does not support appendBuffer";
        }

        public function endOfStream():void{
            throw "RTMPVideoProvider does not support endOfStream";
        }

        public function abort():void{
            throw "RTMPVideoProvider does not support abort";
        }

        public function discontinuity():void{
            throw "RTMPVideoProvider does not support discontinuities";
        }

        public function get buffered():Array{
            if(duration > 0){
                return [[0, duration]];
            }
            else{
                return [];
            }
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
            return _isPlaying;
        }

        public function get paused():Boolean{
            return _isPaused;
        }

        public function get ended():Boolean{
            return _reportEnded;
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
            _hasDuration = false;
            if(_isPlaying){
                _ns.close();
                _loadErrored = false;
                _loadStarted = false;
                _loadCompleted = false;
                _src = pSrc;
                initNetConnection();
            }
            else{
                init(pSrc, false);
            }
        }

        public function get srcAsString():String{
            if(_src != null){
                return _src.url;
            }
            return "";
        }

        public function init(pSrc:Object, pAutoplay:Boolean):void{
            _src = pSrc;
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
            if(pAutoplay){
                play();
            }
        }

        public function load():void{
            _pauseOnStart = true;
            _isPlaying = false;
            _isPaused = true;
            initNetConnection();
        }

        public function play():void{
            // if this is a fresh playback request
            if(!_loadStarted){
                _pauseOnStart = false;
                _isPlaying = false;
                _isPaused = false;
                _metadata = {};
                initNetConnection();
            }
            // if the asset is paused
            else if(_isPaused && !_reportEnded){
                _pausePending = false;
                _ns.resume();
                _isPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {}));
            }
            // video playback ended, seek to beginning
            else if(_hasEnded){
                _ns.seek(0);
                _isPlaying = true;
                _isPaused = false;
                _hasEnded = false;
                _reportEnded = false;
                _isBuffering = true;
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            }
        }

        public function pause():void{
            if(_isPlaying && !_isPaused){
                _ns.pause();
                _isPaused = true;
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
                if(_isBuffering){
                    _pausePending = true;
                }
            }
            else if(_hasEnded && !_isPaused) {
                _isPaused = true;
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            }
        }

        public function resume():void{
            if(_isPlaying && _isPaused){
                _ns.resume();
                _isPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            }
        }

        public function adjustCurrentTime(pValue:Number):void {
            // no-op
        }

        public function seekBySeconds(pTime:Number):void{
            if(_isPlaying){
                _isSeeking = true;
                _throughputTimer.stop();
                _ns.seek(pTime);
                _isBuffering = true;
            }
            else if(_hasEnded){
                _ns.seek(pTime);
                _isPlaying = true;
                _hasEnded = false;
                _reportEnded = false;
                _isBuffering = true;
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            }
        }

        public function seekByPercent(pPercent:Number):void{
            if(_isPlaying && _metadata.duration != undefined){
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
            if(_isPlaying){
                _ns.close();
                _isPlaying = false;
                _hasEnded = true;
                _reportEnded = true;
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
                try {
                    _throughputTimer.stop();
                    _throughputTimer = null;
                } catch( err: Error ) {

                }
            }

            if(_rtmpRetryTimer)
            {
                try {
                    _rtmpRetryTimer.stop();
                    _rtmpRetryTimer = null;
                } catch( err: Error ) {

                }
            }
        }

        private function initNetConnection():void{
            if(_nc == null){
                _nc = new NetConnection();
                _nc.proxyType = 'best'; // needed behind firewalls
                _nc.client = this;
                _nc.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
            }

            // initiating an RTMP connection carries some overhead, so if we're already connected
            // to a server, and that server is the same as the one that hosts whatever we're trying to
            // play, we should skip straight to the playback
            if(_nc.connected){
                if(_src.connectionURL != _nc.uri){
                    _nc.connect(_src.connectionURL);
                }
                else{
                    initNetStream();
                }
            }
            else{
                _nc.connect(_src.connectionURL);
            }
        }

        private function initNetStream():void{
            if(_ns != null){
                _ns.removeEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
                _ns = null;
            }
            _ns = new NetStream(_nc);
            _ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
            _ns.client = this;
            _ns.bufferTime = 1;
            _ns.play(_src.streamURL);
            _videoReference.attachNetStream(_ns);
            _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_READY, {ns:_ns}));
        }

        private function calculateThroughput():void{
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

        private function onRTMPRetryTimerTick(e:TimerEvent):void{
            initNetConnection();
        }

        private function onNetConnectionStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetConnection.Connect.Success":
                    _model.broadcastEventExternally(ExternalEventName.ON_RTMP_CONNECT_SUCCESS);
                    _nc.call("FCSubscribe", null, _src.streamURL); // try to subscribe
                    initNetStream();
                    break;
                case "NetConnection.Connect.Failed":
                    if(_ncRTMPCurrentRetry < _ncRTMPRetryThreshold){
                        _ncRTMPCurrentRetry++;
                        _model.broadcastErrorEventExternally(ExternalErrorEventName.RTMP_CONNECT_FAILURE);
                        _rtmpRetryTimer.start();
                        _model.broadcastEventExternally(ExternalEventName.ON_RTMP_RETRY);
                    }
                    break;
                default:

                    if(e.info.level == "error"){
                        _model.broadcastErrorEventExternally(e.info.code);
                        _model.broadcastErrorEventExternally(e.info.description);
                    }

                    break;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETCONNECTION_STATUS, {info:e.info}));
        }

        private function onNetStreamStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetStream.Play.Reset":
                    break;
                case "NetStream.Play.Start":
                    _canPlayThrough = false;
                    _hasEnded = false;
                    _reportEnded = false;
                    _isBuffering = true;
                    _currentThroughput = 0;
                    _loadStartTimestamp = getTimer();
                    _throughputTimer.reset();
                    _throughputTimer.start();
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    if(_pauseOnStart && _loadStarted == false){
                        _ns.pause();
                        _isPaused = true;
                    }
                    else{
                        if (!_isPlaying) {
                            _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                        }
                        _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:e.info}));
                    }
                    _loadStarted = true;
                    break;

                case "NetStream.Buffer.Full":
                    _isBuffering = false;
                    _isPlaying = true;
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                    _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                    if(_pausePending){
                        _pausePending = false;
                        _ns.pause();
                        _isPaused = true;
                    }
                    break;

                case "NetStream.Buffer.Empty":
                    // playback is over
                    if (_hasEnded) {
                        if(!_loop){
                            _isPlaying = false;
                            _hasEnded = true;
                            _reportEnded = true;
                            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {info:e.info}));
                            _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                        }
                        else{
                            _ns.seek(0);
                        }
                    }
                    // other stream buffering
                    else {
                        _isBuffering = true;
                        _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    }

                    break;

                case "NetStream.Play.Stop":
                    _hasEnded = true;
                    _throughputTimer.stop();
                    _throughputTimer.reset();
                    break;

                case "NetStream.Seek.Notify":
                    _isPlaying = true;
                    _isSeeking = false;
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_SEEK_COMPLETE, {info:e.info}));
                    _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
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

                default:
                    if(e.info.level == "error"){
                        _model.broadcastErrorEventExternally(e.info.code);
                        _model.broadcastErrorEventExternally(e.info.description);
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
                if (!_hasDuration) {
                    _hasDuration = true;
                    _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _metadata.duration);
                }
            }
            else{
                _isLive = true;
                _canSeekAhead = false;
            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_META_DATA, {metadata:_metadata}));
            _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
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

        /**
         * Called from FMS during bandwidth detection
         */
        public function onBWCheck(... pRest):Number {
            return 0;
        }

        /**
         * Called from FMS when bandwidth detection is completed.
         */
        public function onBWDone(... pRest):void {
            // no op for now but needed by NetConnection
        }

        /**
         * Called from FMS when subscribing to live streams.
         */
        public function onFCSubscribe(pInfo:Object):void {
            initNetStream();
        }

        /**
         * Called from FMS when unsubscribing to live streams.
         */
        public function onFCUnsubscribe(pInfo:Object):void {
            // no op for now but needed by NetConnection
        }

        /**
         * Called from FMS for NetStreams. Incorrectly used for NetConnections as well.
         * This is here to prevent runtime errors.
         */
        public function streamInfo(pObj:Object):void {}
    }
}
