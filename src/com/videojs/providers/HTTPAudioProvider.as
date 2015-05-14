package com.videojs.providers{

    import com.videojs.VideoJSModel;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;

    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.Video;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.utils.getTimer;
    import flash.external.ExternalInterface;


    public class HTTPAudioProvider implements IProvider{

        private var _throughputTimer:Timer;
        private var _currentThroughput:int = 0; // in B/sec
        private var _loadStartTimestamp:int;
        private var _loadStarted:Boolean = false;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _isBuffering:Boolean = false;
        private var _src:Object;
        private var _metadata:Object;
        private var _loop:Boolean = false;
        private var _preloadInitiated:Boolean = false;

        private var _sound:Sound;
        private var _soundChannel:SoundChannel;
        private var _audioPlaybackPaused:Boolean = true;
        private var _audioIsSeeking:Boolean = false;
        private var _audioPlaybackHasEnded:Boolean = false;
        private var _audioBytesLoaded:int = 0;
        private var _audioBytesTotal:int = 0;
        private var _audioDuration:Number = 0;
        private var _audioPausePoint:Number = 0;
        private var _estimatedDurations:int = 0;
        private var _canPlayThroughDispatched:Boolean = false;

        private var _model:VideoJSModel;

        public function HTTPAudioProvider(){
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
            if(_soundChannel){
                return _soundChannel.position / 1000;
            }
            else{
                return _audioPausePoint / 1000;
            }
        }

        public function get duration():Number{
            return _audioDuration / 1000;
        }

        public function get readyState():int{
            if(_canPlayThroughDispatched){
                return 4;
            }
            else if(_loadCompleted){
                return 3;
            }
            else if(_loadStarted){
                return 2;
            }
            else if(_estimatedDurations >= 5){
                return 1;
            }
            else{
                return 0;
            }
        }

        public function get networkState():int{
            if(_loadErrored){
                return 3;
            }
            else if(_loadStarted){
                return 2;
            }
            else{
                return 1;
            }
        }

        public function appendBuffer(bytes:ByteArray):void{
            throw "HTTPAudioProvider does not support appendBuffer";
        }

        public function endOfStream():void{
            throw "HTTPAudioProvider does not support endOfStream";
        }

        public function abort():void{
            throw "HTTPAudioProvider does not support abort";
        }

        public function discontinuity():void{
            throw "HTTPAudioProvider does not support discontinuities";
        }

        public function get buffered():Number{
            if(duration > 0){
                return (bytesLoaded / bytesTotal) * duration;
            }
            return 0;
        }

        public function get bufferedBytesEnd():int{
            return _audioBytesLoaded;
        }

        public function get bytesLoaded():int{
            return _audioBytesLoaded;
        }

        public function get bytesTotal():int{
            return _audioBytesTotal;
        }

        public function get playing():Boolean{
            return _soundChannel != null;
        }

        public function get paused():Boolean{
            return _audioPlaybackPaused || _audioPlaybackHasEnded;
        }

        public function get ended():Boolean{
            return _audioPlaybackHasEnded;
        }

        public function get seeking():Boolean{
            return _audioIsSeeking;
        }

        public function get usesNetStream():Boolean{
            return false;
        }

        public function get metadata():Object{
            return _metadata;
        }

        public function get srcAsString():String{
            if(_src != null && _src.path != undefined){
                return _src.path;
            }
            return "";
        }

        public function set src(pSrc:Object):void{
            _src = pSrc;
        }

        public function init(pSrc:Object, pAutoplay:Boolean):void{
            _src = pSrc;
            if(pAutoplay){
               play();
            }
        }

        public function load():void{
            _preloadInitiated = true;

            // if we're already playing
            if(_soundChannel){
                _stop();
                _throughputTimer.stop();
                _throughputTimer.reset();
            }

            if(_sound == null){
                _sound = new Sound();
                _sound.addEventListener(IOErrorEvent.IO_ERROR, onSoundLoadError);
                _sound.addEventListener(ProgressEvent.PROGRESS, onSoundProgress);
                _sound.addEventListener(Event.COMPLETE, onSoundLoadComplete);
                _sound.addEventListener(Event.OPEN, onSoundOpen);
                _sound.addEventListener(Event.ID3, onID3Loaded);
            }

            // initialize the asset
            _audioPlaybackPaused = true;
            _audioPlaybackHasEnded = false;
            _audioBytesLoaded = 0;
            _audioBytesTotal = 0;
            _audioDuration = 0;
            _audioPausePoint = 0;
            _estimatedDurations = 0;
            _canPlayThroughDispatched = false;
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;

            if(_src){
                var __request:URLRequest = new URLRequest(_src.path);
                try{
                    _sound.load(__request);
                }
                catch(e:Error){
                    _model.broadcastErrorEventExternally("audioloaderror");
                }
                _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
            }
        }

        public function play():void{
            if(_soundChannel) {
                return;
            }

            if(_preloadInitiated){
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                _soundChannel = _sound.play(_audioPausePoint);
                _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                _audioPlaybackPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_START);
                return;
            }

            load();
            play();
        }

        public function pause():void{
            if(_soundChannel){
                _audioPausePoint = _soundChannel.position;
                _stop();
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            }
        }

        public function resume():void{
            if(_audioPlaybackPaused){
                _stop();
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                _soundChannel = _sound.play(_audioPausePoint);
                _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                _audioPlaybackPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_START);
            }
        }

        public function stop():void{
            if(_soundChannel){
                _stop();
                _audioPausePoint = 0;
                _audioPlaybackHasEnded = false;
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            }
        }

        public function seekBySeconds(pTime:Number):void{
            if(_audioDuration > 0){
                _stop();
                _soundChannel = _sound.play(int(pTime * 1000));
                _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                _audioPlaybackHasEnded = false;
                _audioPlaybackPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
            }
        }

        public function seekByPercent(pPercent:Number):void{
            if(_audioDuration > 0){
                _stop();
                _soundChannel = _sound.play(pPercent * _audioDuration);
                _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                _audioPlaybackHasEnded = false;
                _audioPlaybackPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
            }
        }

        public function attachVideo(pVideo:Video):void{}

        public function die():void{
            if(_soundChannel){
                try{
                    _stop();
                }catch(err:Error){

                }
            }

            if(_throughputTimer){
                try{
                    _throughputTimer.stop();
                    _throughputTimer = null;
                }catch(err: Error){

                }
            }
        }

        private function doLoadCalculations():void{
            // if the load is finished
            if(_sound.bytesLoaded == _sound.bytesTotal){
                _loadCompleted = true;
                _audioDuration = _sound.length;
                _throughputTimer.stop();
                _throughputTimer.reset();
                _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _audioDuration);
                _canPlayThroughDispatched = true;
                _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
            }
            else{
                var __percentLoaded:Number = _sound.bytesLoaded / _sound.bytesTotal;
                _audioDuration = _sound.length * (1 / __percentLoaded);
                _estimatedDurations++;
                // once we have 5 measurements
                if(_estimatedDurations == 5){
                    _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _audioDuration);
                }
                else if(_estimatedDurations > 5){
                    var __throughput:Number = _sound.bytesLoaded / ((getTimer() - _loadStartTimestamp) / 1000);
                    var __timeToLoad:Number = (_sound.bytesTotal - _sound.bytesLoaded) / __throughput;
                    if(!_canPlayThroughDispatched && __timeToLoad <  _audioDuration){
                        _canPlayThroughDispatched = true;
                        _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY_THROUGH);
                    }
                }
            }
        }

        private function onThroughputTimerTick(e:TimerEvent):void{
            doLoadCalculations();
        }

        private function onSoundProgress(e:ProgressEvent):void{
            _audioBytesLoaded = e.bytesLoaded;
            _audioBytesTotal = e.bytesTotal;
            _audioDuration = _sound.length
        }

        private function onSoundOpen(e:Event):void{
            _loadStarted = true;
            _loadStartTimestamp = getTimer();
            _throughputTimer.start();
        }

        private function onSoundLoadComplete(e:Event):void{
            _loadCompleted = true;
            _throughputTimer.stop();
            _throughputTimer.reset();
            doLoadCalculations();
        }

        private function onSoundPlayComplete(e:Event):void{
            if(!_loop){
                _audioPlaybackHasEnded = true;
                _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
            }
            else{
                // if we know the duration
                if(_audioDuration > 0){
                    _stop();
                    _soundChannel = _sound.play(0);
                    _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                    _audioPlaybackPaused = false;
                }
            }
        }

        private function onSoundLoadError(e:IOErrorEvent):void{
            _loadErrored = true;
            _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
        }

        private function onID3Loaded(event:Event):void{
            _metadata = {
                id3:_sound.id3
            }
            _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
        }

        private function _stop():void{
            if(_soundChannel){
                _soundChannel.stop();
                _soundChannel = null;
                _audioPlaybackPaused = true;
            }
        }
    }
}
