package com.videojs.providers{
    
    import com.videojs.VideoJSModel;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.TimerEvent;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.Video;
    import flash.net.URLRequest;
    import flash.utils.Timer;
    
    
    public class HTTPAudioProvider implements IProvider{
        
        private var _throughputTimer:Timer;
        private var _currentThroughput:int = 0; // in B/sec
        private var _loadStartTimestamp:int;
        private var _loadStarted:Boolean = false;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _isPlaying:Boolean = false;
        private var _isPaused:Boolean = true;
        private var _isBuffering:Boolean = false;
        private var _canSeekAhead:Boolean = false;
        private var _canPlayThrough:Boolean = false;
        private var _src:Object;
        private var _metadata:Object;
        private var _loop:Boolean = false;
        
        private var _sound:Sound;
		private var _soundChannel:SoundChannel;
        private var _audioPlaybackStarted:Boolean = false;
        private var _audioPlaybackStopped:Boolean = false;
        private var _audioPlaybackPaused:Boolean = false;
        private var _audioIsSeeking:Boolean = false;
        private var _audioPlaybackHasEnded:Boolean = false;
        private var _audioBytesLoaded:int = 0;
        private var _audioBytesTotal:int = 0;
        private var _audioDuration:Number = 0;
        private var _audioPausePoint:Number = 0;
        
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
            if(_audioPlaybackStarted){
                return _soundChannel.position / 1000;
            }
            else{
                return 0;
            }
        }
        
        public function get duration():Number{
            return _audioDuration;
        }
        
        public function get readyState():int{
            return 0;
        }
        
        public function get networkState():int{
            return 0;
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
            return _isPlaying;
        }
        
        public function get paused():Boolean{
            return _audioPlaybackPaused;
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
            if(_src != null){
                return _src.url;
            }
            return "";
        }
        
        public function set src(pSrc:Object):void{
            _src = pSrc;
        }
        
        public function init(pSrc:Object):void{
            _src = pSrc;
            _loadErrored = false;
            _loadStarted = false;
            _loadCompleted = false;
        }
        
        public function load():void
        {
        }
        
        public function play():void{
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
                    _sound.addEventListener(Event.ID3, onID3Loaded);
                }
                        
                // play the asset
                _audioPlaybackStarted = false;
                _audioPlaybackStopped = false;
                _audioPlaybackPaused = false;
                _audioBytesLoaded = 0;
                _audioBytesTotal = 0;
                _audioDuration = 0;
                _audioPausePoint = 0;
                var __request:URLRequest = new URLRequest(_src.path);
                try{
                    _sound.load(__request);
                }
                catch(e:Error){
                    _model.broadcastErrorEventExternally("audioloaderror");
                }
                _soundChannel = _sound.play();
                _soundChannel.addEventListener(Event.SOUND_COMPLETE, onSoundPlayComplete);
                _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
                _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
            }
        }
        
        public function pause():void{
            if(_audioPlaybackStarted){
                _audioPausePoint = _soundChannel.position;
                _soundChannel.stop();
                _audioPlaybackPaused = true;
            }
        }
        
        public function resume():void{
            if(_audioPlaybackStarted){
                _soundChannel = _sound.play(_audioPausePoint);
                _audioPlaybackPaused = false;
            }
        }
        
        public function seekBySeconds(pTime:Number):void{
            if(_audioDuration > 0){
                _soundChannel.stop();
                _soundChannel = _sound.play(int(pTime * 1000));
                _audioPlaybackStarted = true;
                _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
            }
        }
        
        public function seekByPercent(pPercent:Number):void
        {
        }
        
        public function stop():void{
            if(_audioPlaybackStarted){
                _soundChannel.stop();
                _audioPlaybackStarted = false;
                _audioPlaybackStopped = true;
            }
        }
        
        public function attachVideo(pVideo:Video):void
        {
        }
        
        public function die():void
        {
        }
        
        private function calculateThroughput():void{
            
        }
        
        private function onThroughputTimerTick(e:TimerEvent):void{
            calculateThroughput();
        }
        
        private function onSoundProgress(e:ProgressEvent):void{
            _audioBytesLoaded = e.bytesLoaded;
            _audioBytesTotal = e.bytesTotal;
            _audioDuration = _sound.length
        }
        
        private function onSoundOpen(e:Event):void{
            _audioPlaybackStarted = true;
            _model.broadcastEventExternally(ExternalEventName.ON_START);
        }

        private function onSoundLoadComplete(e:Event):void{
            _audioDuration = _sound.length / 1000;
        }
		
        private function onSoundPlayComplete(e:Event):void{
            
            if(!_loop){
                _isPlaying = false;
                _audioPlaybackHasEnded = true;
                _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
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
            _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
        }
        
        private function onID3Loaded(event:Event):void{
            _metadata = {
                id3:_sound.id3
            }
            _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);
        }
    }
}