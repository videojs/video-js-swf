package com.videojs{
    
    import com.videojs.events.VideoJSEvent;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.structs.PlaybackType;
    import com.videojs.structs.PlayerMode;
    
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IEventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.NetStatusEvent;
    import flash.events.ProgressEvent;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.SoundMixer;
    import flash.media.SoundTransform;
    import flash.media.Video;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.net.URLRequest;
    import flash.utils.Timer;
    import flash.utils.getTimer;
    
    public class VideoJSModel extends EventDispatcher{

        private var _nc:NetConnection;
        private var _ns:NetStream;
        private var _ncRTMPRetryThreshold:int = 3;
        private var _ncRTMPCurrentRetry:int = 0;
        private var _rtmpRetryTimer:Timer;
        private var _masterVolume:SoundTransform;
        private var _currentPlaybackType:String;
        private var _videoReference:Video;
        private var _pauseOnStart:Boolean = false;
        private var _lastSetVolume:Number = 1;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _throughputTimer:Timer;
        private var _currentThroughput:int = 0; // in B/sec
        private var _loadStartTimestamp:int;
        private var _pausePending:Boolean = false;
        private var _canPlayThrough:Boolean = false;
        
        // audio playback - will be classed out in a forthcoming update
		private var _sound:Sound;
		private var _soundChannel:SoundChannel;
        private var _audioPlaybackStarted:Boolean = false;
        private var _audioPlaybackStopped:Boolean = false;
        private var _audioPlaybackPaused:Boolean = false;
        private var _audioBytesLoaded:int;
        private var _audioBytesTotal:int;
        private var _audioDuration:Number = 0;
        private var _audioPausePoint:Number = 0;
        
        // accessible properties
        private var _mode:String;
        private var _stageRect:Rectangle;
        private var _jsEventProxyName:String = "";
        private var _jsErrorEventProxyName:String = "";
        private var _backgroundColor:Number = 0;
        private var _volume:Number = 1;
        private var _streamMetaData:Object;
        private var _rtmpConnectionURL:String = "";
        private var _rtmpStream:String = "";
        private var _loadStarted:Boolean = false;
        private var _isPlaying:Boolean = false;
        private var _isPaused:Boolean = true;
        private var _isBuffering:Boolean = false;
        private var _isSeeking:Boolean = false;
        private var _isLive:Boolean = false;
        private var _canSeekAhead:Boolean = false;
        private var _hasEnded:Boolean = false;
        private var _autoplay:Boolean = false;
        private var _preload:Boolean = false;
        private var _loop:Boolean = false;
        private var _src:String = "";
        private var _poster:String = "";
        
        private static var _instance:VideoJSModel;
        
        public function VideoJSModel(pLock:SingletonLock){
            if (!pLock is SingletonLock) {
                throw new Error("Invalid Singleton access.  Use VideoJSModel.getInstance()!");
            }
            else{
                _mode = PlayerMode.VIDEO;
                _streamMetaData = {};
                _rtmpRetryTimer = new Timer(25, 1);
                _rtmpRetryTimer.addEventListener(TimerEvent.TIMER, onRTMPRetryTimerTick);
                _currentPlaybackType = PlaybackType.HTTP;
                _masterVolume = new SoundTransform();
                _stageRect = new Rectangle(0, 0, 100, 100);
                _throughputTimer = new Timer(250, 0);
                _throughputTimer.addEventListener(TimerEvent.TIMER, onThroughputTimerTick);
            }
        }
        
        public static function getInstance():VideoJSModel {
            if (_instance === null){
                _instance = new VideoJSModel(new SingletonLock());
            }
            return _instance;
        }
        
        public function get mode():String{
            return _mode;
        }
        public function set mode(pMode:String):void{
            switch(pMode){
                case PlayerMode.VIDEO:
                    _mode = pMode;
                    break;
                case PlayerMode.AUDIO:
                    _mode = pMode;
                    break;
                default:
                    broadcastEventExternally(ExternalErrorEventName.UNSUPPORTED_MODE);
            }
            
        }
        
        public function get jsEventProxyName():String{
            return _jsEventProxyName;
        }
        public function set jsEventProxyName(pName:String):void{
            _jsEventProxyName = pName;
        }
        
        public function get jsErrorEventProxyName():String{
            return _jsErrorEventProxyName;
        }
        public function set jsErrorEventProxyName(pName:String):void{
            _jsErrorEventProxyName = pName;
        }
        
        public function get stageRect():Rectangle{
            return _stageRect;
        }
        public function set stageRect(pRect:Rectangle):void{
            _stageRect = pRect;
        }
        
        public function get backgroundColor():Number{
            return _backgroundColor;
        }
        public function set backgroundColor(pColor:Number):void{
            if(pColor < 0){
                _backgroundColor = 0;
            }
            else{
                _backgroundColor = pColor;
                broadcastEvent(new VideoPlaybackEvent(VideoJSEvent.BACKGROUND_COLOR_SET, {}));
            }
        }
        
        public function get videoReference():Video{
            return _videoReference;
        }
        public function set videoReference(pVideo:Video):void{
            _videoReference = pVideo;
        }
        
        public function get metadata():Object{
            return _streamMetaData;
        }
        
        public function get volume():Number{
            return _volume;
        }
        public function set volume(pVolume:Number):void{
            if(pVolume >= 0 && pVolume <= 1){
                _volume = pVolume;
            }
            else{
                _volume = 1;
            }
            _masterVolume.volume = _volume;
            SoundMixer.soundTransform = _masterVolume;
            _lastSetVolume = _volume;
            broadcastEventExternally(ExternalEventName.ON_VOLUME_CHANGE, _volume);
        }
        
        public function get duration():Number{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                
                    if(_streamMetaData != null && _streamMetaData.duration != undefined){
                        return Number(_streamMetaData.duration);
                    }
                    else{
                        return 0;
                    }
                
                    break;
                
                case PlayerMode.AUDIO:
                    
                    return _audioDuration;
                    
                    break;
                
                default:
                    
                    return 0;
                    break;
            }

        }
        
        public function get autoplay():Boolean{
            return _autoplay;
        }
        public function set autoplay(pValue:Boolean):void{
            _autoplay = pValue;
        }
        
        public function get src():String{
            return _src;
        }
        public function set src(pValue:String):void{
            _src = pValue;
            _rtmpConnectionURL = "";
            _rtmpStream = "";
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
            _currentPlaybackType = PlaybackType.HTTP;
            broadcastEventExternally(ExternalEventName.ON_SRC_CHANGE, _src);
            if(_autoplay){
                play();
            }
            else if(_preload){
                load();
            }
        }
        
        public function get rtmpConnectionURL():String{
            return _rtmpConnectionURL;
        }
        public function set rtmpConnectionURL(pURL:String):void{
            _rtmpConnectionURL = pURL;
        }
        
        public function get rtmpStream():String{
            return _rtmpStream;
        }
        public function set rtmpStream(pValue:String):void{
            _src = "";
            _currentPlaybackType = PlaybackType.RTMP;
            broadcastEventExternally(ExternalEventName.ON_SRC_CHANGE, _src);
            _rtmpStream = pValue;
            if(_autoplay){
                play();
            }
        }
        
        /**
         * This is used to distinguish a _src that's being set from incoming flashvars,
         * and mirrors the normal setter WITHOUT dispatching the 'onsrcchange' event.
         * 
         * @param pValue
         * 
         */        
        public function set srcFromFlashvars(pValue:String):void{
            _src = pValue;
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
            _currentPlaybackType = PlaybackType.HTTP
            if(_autoplay){
                play();
            }
            else if(_preload){
                load();
            }
        }
        
        
        public function get poster():String{
            return _poster;
        }
        public function set poster(pValue:String):void{
            _poster = pValue;
            broadcastEvent(new VideoJSEvent(VideoJSEvent.POSTER_SET));
        }
        
        public function get hasEnded():Boolean{
            return _hasEnded;
        }
        
        /**
         * Returns the playhead position of the current video, in seconds. 
         * @return 
         * 
         */        
        public function get time():Number{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                    
                    if(_ns != null){
                        return _ns.time;
                    }
                    else{
                        return 0;
                    }
                    
                    break;
                
                case PlayerMode.AUDIO:
                    
                    if(_audioPlaybackStarted){
                        return _soundChannel.position/1000;
                    }
                    else{
                        return 0;
                    }
                    
                    break;
                
                default:
                    
                    return 0;
                    break;
                
            }
        }
        
        public function get muted():Boolean{
            return (_volume == 0);
        }
        public function set muted(pValue:Boolean):void{
            if(pValue){
                volume = 0;
            }
            else{
                volume = _lastSetVolume;
            }
        }
        
        public function get seeking():Boolean{
            return _isSeeking;
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
        
        public function get readyState():int{
            // if we have metadata and a known duration
            if(_streamMetaData != null && _streamMetaData.duration != undefined){
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
        
        public function get preload():Boolean{
            return _preload;
        }
        public function set preload(pValue:Boolean):void{
            _preload = pValue;
        }
        
        public function get loop():Boolean{
            return _loop;
        }
        public function set loop(pValue:Boolean):void{
            _loop = pValue;
        }
        
        public function get buffered():Number{
            if(duration > 0){
                if(_currentPlaybackType == PlaybackType.HTTP){
                    return (_ns.bytesLoaded / _ns.bytesTotal) * duration;
                }
                else{
                    return duration;
                }
                
            }
            else{
                return 0;
            }
        }
        
        /**
         * Returns the total number of bytes loaded for the current video.
         * @return 
         * 
         */
        public function get bufferedBytesEnd():int{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                    
                    if(_loadStarted){
                        return _ns.bytesLoaded;
                    }
                    else{
                        return 0;
                    }
                    
                    break;
                
                case PlayerMode.AUDIO:
                    
                    return _audioBytesLoaded;
                    
                    break;
                
                default:
                    return 0;
                    break;
                
            }

        }
        
        /**
         * Returns the total size of the current video, in bytes.
         * @return 
         * 
         */
        public function get bytesTotal():int{
            switch(_mode){
                case PlayerMode.VIDEO:
                    if(_loadStarted){
                        return _ns.bytesTotal;
                    }
                    else{
                        return 0;
                    }
                    break;
                case PlayerMode.AUDIO:
                    return _audioBytesTotal;
                    break;
                default:
                    return 0;
                    break;
            }
        }
        
        /**
         * Returns the pixel width of the currently playing video as interpreted by the decompressor.
         * @return 
         * 
         */        
        public function get videoWidth():int{
            if(_videoReference != null){
                return _videoReference.videoWidth;
            }
            else{
                return 0;
            }
        }
        
        /**
         * Returns the pixel height of the currently playing video as interpreted by the decompressor. 
         * @return 
         * 
         */        
        public function get videoHeight():int{
            if(_videoReference != null){
                return _videoReference.videoHeight;
            }
            else{
                return 0;
            }
        }
        
        public function get playing():Boolean{
            return _isPlaying;
        }
        
        public function get paused():Boolean{
            switch(_mode){
                case PlayerMode.VIDEO:
                    return _isPaused;
                    break;
                case PlayerMode.AUDIO:
                    return _audioPlaybackPaused;
                    break;
                default:
                    return false;
                    break;
            }
        }

        /**
         * Allows this model to act as a centralized event bus to which other classes can subscribe.
         *  
         * @param e
         * 
         */        
        public function broadcastEvent(e:Event):void{
            dispatchEvent(e); 
        }
        
        /**
         * This is an internal proxy that allows instances in this swf to broadcast events to a JS proxy function, if one is defined.
         * @param args
         * 
         */        
        public function broadcastEventExternally(... args):void{
            if(_jsEventProxyName != ""){
                if(ExternalInterface.available){
                    var __incomingArgs:* = args as Array;
                    var __newArgs:Array = [_jsEventProxyName, ExternalInterface.objectID].concat(__incomingArgs);
                    ExternalInterface.call.apply(null, __newArgs);
                }
            }
        }
        
        /**
         * This is an internal proxy that allows instances in this swf to broadcast error events to a JS proxy function, if one is defined.
         * @param args
         * 
         */        
        public function broadcastErrorEventExternally(... args):void{
            if(_jsErrorEventProxyName != ""){
                if(ExternalInterface.available){
                    var __incomingArgs:* = args as Array;
                    var __newArgs:Array = [_jsErrorEventProxyName, ExternalInterface.objectID].concat(__incomingArgs);
                    ExternalInterface.call.apply(null, __newArgs);
                }
            }
        }
        
        /**
         * Loads the video in a paused state. 
         * 
         */        
        public function load():void{
            switch(_mode){
                case PlayerMode.VIDEO:
                    _pauseOnStart = true;
                    _isPlaying = false;
                    _isPaused = true;
                    initNetConnection();
                    break;
            }
        }
        
        /**
         * Loads the video and begins playback immediately.
         * 
         */        
        public function play():void{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                    
                    // if this is a fresh playback request
                    if(!_loadStarted){
                        _pauseOnStart = false;
                        _isPlaying = false;
                        _isPaused = false;
                        _streamMetaData = {};
                        initNetConnection();
                    }
                    // if the asset is already loading
                    else{
                        ExternalInterface.call("console.log", "Trying to resume!");
                        _pausePending = false;
                        _ns.resume();
                        _isPaused = false;
                        broadcastEventExternally(ExternalEventName.ON_RESUME);
                        broadcastEventExternally(ExternalEventName.ON_START);
                        broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {}));
                    }
                    
                    break;
                
                case PlayerMode.AUDIO:

                    if(_src != ""){
                        
                        // if we're already playing
                        if(_audioPlaybackStarted){
                            _soundChannel.stop();
                        }
                        else{
                            _sound = new Sound();
                            _sound.addEventListener(IOErrorEvent.IO_ERROR, onSoundLoadError);
                            _sound.addEventListener(ProgressEvent.PROGRESS, onSoundProgress);
                            _sound.addEventListener(Event.COMPLETE, onSoundLoadComplete);
                            _sound.addEventListener(Event.OPEN, onSoundOpen);
                        }
                        
                        // play the asset
                        _audioPlaybackStarted = false;
                        _audioPlaybackStopped = false;
                        _audioPlaybackPaused = false;
                        _audioBytesLoaded = 0;
                        _audioBytesTotal = 0;
                        _audioDuration = 0;
                        _audioPausePoint = 0;
                        var __request:URLRequest = new URLRequest(_src);
                        try{
                            _sound.load(__request);
                        }
                        catch(e:Error){
                            broadcastErrorEventExternally("audioloaderror");
                        }
                        _soundChannel = _sound.play();
                        _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                        broadcastEventExternally(ExternalEventName.ON_LOAD_START);
                        broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    }
                    
                    break;

            }
        }
        
        /**
         * Pauses video playback. 
         * 
         */        
        public function pause():void{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                    
                    if(_isPlaying && !_isPaused){
                        _ns.pause();
                        _isPaused = true;
                        broadcastEventExternally(ExternalEventName.ON_PAUSE);
                        if(_isBuffering){
                            _pausePending = true;
                        }
                    }
                    break;
                
                case PlayerMode.AUDIO:
                    
                    if(_audioPlaybackStarted){
                        _audioPausePoint = _soundChannel.position;
                        _soundChannel.stop();
                        _audioPlaybackPaused = true;
                    }
                    break;
            }
        }
        
        /**
         * Resumes video playback. 
         * 
         */        
        public function resume():void{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
            
                    if(_isPlaying && _isPaused){
                        _ns.resume();
                        _isPaused = false;
                        broadcastEventExternally(ExternalEventName.ON_RESUME);
                        broadcastEventExternally(ExternalEventName.ON_START);
                    }
                    break;
                
                case PlayerMode.AUDIO:
                    
                    if(_audioPlaybackStarted){
                        _soundChannel = _sound.play(_audioPausePoint);
                        _audioPlaybackPaused = false;
                    }
                    break;
            }
        }
        
        /**
         * Seeks the currently playing video to the closest keyframe prior to the value provided. 
         * @param pValue
         * 
         */        
        public function seekBySeconds(pValue:Number):void{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:

                    if(_isPlaying){
                        _isSeeking = true;
                        _throughputTimer.stop();
                        _ns.seek(pValue);
                        _isBuffering = true;
                    }
                    else if(_hasEnded){
                        _ns.seek(pValue);
                        _isPlaying = true;
                        _hasEnded = false;
                        _isBuffering = true;
                    }
                    
                    break;
                
                case PlayerMode.AUDIO:
                    
                    // if we know the duration
                    if(_audioDuration > 0){
                        _soundChannel.stop();
                        _soundChannel = _sound.play(int(pValue * 1000));
                        _audioPlaybackStarted = true;
                        broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
                    }
                    
                    break;
            }
        }
        
        /**
         * Seeks the currently playing video to the closest keyframe prior to the percent value provided. 
         * @param pValue A float from 0 to 1 that represents the desired seek percent.
         * 
         */        
        public function seekByPercent(pValue:Number):void{
            if(_isPlaying && _streamMetaData.duration != undefined){
                _isSeeking = true;
                if(pValue < 0){
                    _ns.seek(0);
                }
                else if(pValue > 1){
                    _throughputTimer.stop();
                    _ns.seek((pValue / 100) * _streamMetaData.duration);
                }
                else{
                    _throughputTimer.stop();
                    _ns.seek(pValue * _streamMetaData.duration);
                    
                }
            }
        }
        
        /**
         * Stops video playback, clears the video element, and stops any loading proceeses.
         * 
         */        
        public function stop():void{
            
            switch(_mode){
                
                case PlayerMode.VIDEO:
                    
                    if(_isPlaying){
                        _ns.close();
                        _isPlaying = false;
                        _hasEnded = true;
                        broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {}));
                        _throughputTimer.stop();
                        _throughputTimer.reset();
                    }
                    
                    break;
                
                case PlayerMode.AUDIO:
                    
                    if(_audioPlaybackStarted){
                        _soundChannel.stop();
                        _audioPlaybackStarted = false;
                        _audioPlaybackStopped = true;
                    }
                    
                    break;
            }
            
        }

        public function hexToNumber(pHex:String):Number{
            var __number:Number = 0;
            // clean it up
            if(pHex.indexOf("#") != -1){
                pHex = pHex.slice(pHex.indexOf("#")+1);
            }
            if(pHex.length == 6){
                __number = Number("0x"+pHex);
            }
            return __number;
        }
        
        public function humanToBoolean(pValue:*):Boolean{
            if(String(pValue) == "true" || String(pValue) == "1"){
                return true;
            }
            else{
                return false;
            }
        }
        
        private function initNetConnection():void{
            if(_nc == null){
                _nc = new NetConnection();
                _nc.client = this;
                _nc.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
            }
            if(_currentPlaybackType == PlaybackType.HTTP){
                _nc.connect(null);
            }
            else if(_currentPlaybackType == PlaybackType.RTMP){
                if(_rtmpConnectionURL != ""){
                    _nc.connect(_rtmpConnectionURL);
                }
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
            _ns.bufferTime = .5;
            if(_currentPlaybackType == PlaybackType.HTTP){
                _ns.play(_src);
            }
            else if(_currentPlaybackType == PlaybackType.RTMP){
                _ns.play(_rtmpStream);
            }
            _videoReference.attachNetStream(_ns);
            dispatchEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_READY, {ns:_ns}));
        }
        
        private function calculateThroughput():void{
            // if it's finished loading, we can kill the calculations and assume it can play through
            if(_ns.bytesLoaded == _ns.bytesTotal){
                _canPlayThrough = true;
                _loadCompleted = true;
                _throughputTimer.stop();
                _throughputTimer.reset();
                broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
            }
            // if it's still loading, but we know its duration, we can check to see if the current transfer rate
            // will sustain uninterrupted playback - this requires the duration to be known, which is currently
            // only accessible via metadata, which isn't parsed until the Flash Player encounters the metadata atom
            // in the file itself, which means that this logic will only work if the asset is playing - preload
            // won't ever cause this logic to run :(
            else if(_ns.bytesTotal > 0 && _streamMetaData != null && _streamMetaData.duration != undefined){
                _currentThroughput = _ns.bytesLoaded / ((getTimer() - _loadStartTimestamp) / 1000);
                var __estimatedTimeToLoad:Number = (_ns.bytesTotal - _ns.bytesLoaded) * _currentThroughput;
                
                if(__estimatedTimeToLoad <= _streamMetaData.duration){
                    _throughputTimer.stop();
                    _throughputTimer.reset();
                    _canPlayThrough = true;
                    broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
                }
            }
        }
        
        /**
         * This handler is called if an RTMP handshake fails and needs to be retried. 
         * 
         */        
        private function onRTMPRetryTimerTick(e:TimerEvent):void{
            initNetConnection();
        }
        
        private function onNetConnectionStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetConnection.Connect.Success":
                    if(_currentPlaybackType == PlaybackType.RTMP){
                        broadcastEventExternally(ExternalEventName.ON_RTMP_CONNECT_SUCCESS);
                    }
                    initNetStream();
                    break;
                case "NetConnection.Connect.Failed":
                    if(_ncRTMPCurrentRetry < _ncRTMPRetryThreshold){
                        _ncRTMPCurrentRetry++;
                        broadcastErrorEventExternally(ExternalErrorEventName.RTMP_CONNECT_FAILURE);
                        _rtmpRetryTimer.start();
                        broadcastEventExternally(ExternalEventName.ON_RTMP_RETRY);
                    }
                    break;    
            }
            broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETCONNECTION_STATUS, {info:e.info}));
        }
        
        private function onNetStreamStatus(e:NetStatusEvent):void{
            switch(e.info.code){
                case "NetStream.Play.Start":
                    _streamMetaData = null;
                    _canPlayThrough = false;
                    _hasEnded = false;
                    _isBuffering = true;
                    _currentThroughput = 0;
                    _loadStartTimestamp = getTimer();
                    _throughputTimer.reset();
                    _throughputTimer.start();
                    broadcastEventExternally(ExternalEventName.ON_LOAD_START);
                    broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    if(_pauseOnStart && _loadStarted == false){
                        _ns.pause();
                        _isPaused = true;
                    }
                    else{
                        broadcastEventExternally(ExternalEventName.ON_START);
                        broadcastEventExternally(ExternalEventName.ON_RESUME);
                        broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:e.info}));
                    }
                    _loadStarted = true;
                    break;
                
                case "NetStream.Buffer.Full":
                    _isBuffering = false;
                    _isPlaying = true;
                    broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                    broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                    if(_pausePending){
                        _pausePending = false;
                        _ns.pause();
                        _isPaused = true;
                    }
                    break;
                
                case "NetStream.Buffer.Empty":
                    _isBuffering = true;
                    broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    break;
                
                case "NetStream.Play.Stop":
                    
                    if(!_loop){
                        _isPlaying = false;
                        _hasEnded = true;
                        broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {info:e.info}));
                        broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                    }
                    else{
                        _ns.seek(0);
                    }
                    
                    _throughputTimer.stop();
                    _throughputTimer.reset();
                    break;
                
                case "NetStream.Seek.Notify":
                    _isPlaying = true;
                    _isSeeking = false;
                    broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_SEEK_COMPLETE, {info:e.info}));
                    broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
                    broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    _currentThroughput = 0;
                    _loadStartTimestamp = getTimer();
                    _throughputTimer.reset();
                    _throughputTimer.start();
                    
                    break;    
                
                case "NetStream.Play.StreamNotFound":
                    _loadErrored = true;
                    broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
                    break;
                
            }
            broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETSTREAM_STATUS, {info:e.info}));
        }
        
        private function onThroughputTimerTick(e:TimerEvent):void{
            calculateThroughput();
        }
        
        public function onMetaData(pMetaData:Object):void{
            _streamMetaData = pMetaData;
            if(pMetaData.duration != undefined){
                _isLive = false;
                _canSeekAhead = true;
                broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _streamMetaData.duration);
            }
            else{
                _isLive = true;
                _canSeekAhead = false;
            }
            broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_META_DATA, {metadata:pMetaData}));
            broadcastEventExternally(ExternalEventName.ON_METADATA, _streamMetaData);
        }
        
        public function onCuePoint(pInfo:Object):void{
            broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_CUE_POINT, {cuepoint:pInfo}));
        }
        
        public function onXMPData(pInfo:Object):void{
            broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_XMP_DATA, {cuepoint:pInfo}));
        }
        
        public function onPlayStatus(e:Object):void{

        }
        
        private function onSoundProgress(e:ProgressEvent):void{
            _audioBytesLoaded = e.bytesLoaded;
            _audioBytesTotal = e.bytesTotal;
            _audioDuration = _sound.length
        }
        
        private function onSoundOpen(e:Event):void{
            _audioPlaybackStarted = true;
            broadcastEventExternally(ExternalEventName.ON_START);
        }

        private function onSoundLoadComplete(e:Event):void{
            _audioDuration = _sound.length / 1000;
        }
		
        private function onSoundPlayComplete(e:Event):void{
            
            if(!_loop){
                _isPlaying = false;
                _hasEnded = true;
                broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
            }
            else{
                // if we know the duration
                if(_audioDuration > 0){
                    _soundChannel.stop();
                    _soundChannel = _sound.play(0);
                    _audioPlaybackStarted = true;
                }
            }
        }
		
        private function onSoundLoadError(e:IOErrorEvent):void{
            broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
        }
        
    }
}


/**
 * @internal This is a private class declared outside of the package 
 * that is only accessible to classes inside of this file
 * file.  Because of that, no outside code is able to get a 
 * reference to this class to pass to the constructor, which 
 * enables us to prevent outside instantiation.
 * 
 * We do this because Actionscript doesn't allow private constructors,
 * which prevents us from creating a "true" singleton.
 * 
 * @private
 */
class SingletonLock {}