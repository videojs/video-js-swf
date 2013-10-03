package com.videojs.providers.hls{

    import com.videojs.VideoJSModel;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.providers.IProvider;
    import com.videojs.providers.hls.events.HLSEvent;
import com.videojs.providers.hls.utils.HLSRendition;
import com.videojs.providers.hls.utils.ManifestManager;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.utils.Console;

    import flash.events.NetStatusEvent;
    import flash.events.TimerEvent;
    import flash.media.Video;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.net.NetStreamAppendBytesAction;
    import flash.utils.ByteArray;
    import flash.utils.Timer;

    public class HLSVideoProvider implements IProvider{

        private var _nc:NetConnection;
        private var _ns:NetStream;
        private var _videoReference:Video;
        private var _manifestManager:ManifestManager;
        private var _netstreamAuditTimer:Timer;
        private var _netstreamAuditTimerInterval:int = 500;

		/* This is used to belay succcessive seek calls by delaying the execution of the
		 * seek, and resetting the timer on each seek call. Seeking is an expensive
		 * operation in the context of this provider, and we want to avoid having to
		 * handle hundreds of mousemove-initiated seek calls in a short time period.
		 */
		private var _seekDelayTimer:Timer;

        private var _src:Object;
        private var _metadata:Object;
        private var _isPlaying:Boolean = false;
        private var _isPaused:Boolean = false;
        private var _isBuffering:Boolean = false;
        private var _isSeeking:Boolean = false;
        private var _isLive:Boolean = false;
        private var _canSeekAhead:Boolean = true;
        private var _hasEnded:Boolean = false;
        private var _canPlayThrough:Boolean = false;
        private var _loop:Boolean = false;
        private var _targetSeekTime:Number = 0;
		private var _cachedSeekTime:Number = 0;
        private var _pauseOnStart:Boolean = false;
        private var _streamEndImminent:Boolean = false;

        private var _model:VideoJSModel;

        private static const NETSTREAM_PLAY_BUFFER_START_SIZE:Number = 1;
        private static const NETSTREAM_PLAY_BUFFER_END_SIZE:Number = 5;

        public function HLSVideoProvider(){

            _model = VideoJSModel.getInstance();
            _metadata = {};
            _netstreamAuditTimer = new Timer(_netstreamAuditTimerInterval, 0);
            _netstreamAuditTimer.addEventListener(TimerEvent.TIMER, onNetStreamAuditTimerTick);
			_seekDelayTimer = new Timer(200, 0);
			_seekDelayTimer.addEventListener(TimerEvent.TIMER, onSeekDelayTimerTick);

        }

		/* --- ADD MBR Support Start --- */

		public function get isDynamicStream():Boolean {
			return (_manifestManager) ? _manifestManager.isDynamicStream : false;
		}

		public function get initialIndex():int {
			return (_manifestManager) ? _manifestManager.initialIndex : 0;
		}

		public function get currentIndex():int {
			return (_manifestManager) ? _manifestManager.currentIndex : 0;
		}

		public function get currentRendition():HLSRendition {
			return (_manifestManager) ? _manifestManager.currentRendition : null;
		}

		public function get currentBitrate():int {
			return (_manifestManager) ? _manifestManager.currentBitrate : 0;
		}

		public function get autoSwitch():Boolean {
			return (_manifestManager) ? _manifestManager.autoSwitch : false;
		}

		public function get switching():Boolean {
			return (_manifestManager) ? _manifestManager.switching : false;
		}

		public function get maxAllowedIndex():int {
			return (_manifestManager) ? _manifestManager.maxAllowedIndex : 0;
		}

		public function get numDynamicStreams():int {
			return (_manifestManager) ? _manifestManager.numDynamicStreams : 1;
		}

		public function switchTo(pIndex:int):void {
			if( _manifestManager ) {
				_manifestManager.switchTo(pIndex);
			}
		}


		/* --- ADD MBR Support End --- */


		public function get ns():NetStream{
			return _ns;
		}

        public function get loop():Boolean{
            return _loop;
        }

        public function set loop(pLoop:Boolean):void{
            _loop = pLoop;
        }

        public function get time():Number{
            if(_ns != null){
				if(!_isSeeking){
					return _manifestManager.recalculatedPlayheadOffset + _ns.time;
				}
				else{
					return _cachedSeekTime;
				}

            }
            else{
                return 0;
            }
        }

        public function get duration():Number{
            if(_manifestManager){
                return _manifestManager.totalDuration;;
            }
            else{
                return 0;
            }
        }

        public function get readyState():int{
            return 0;
        }

        public function get networkState():int{
            return 0;
        }

        public function get buffered():Number{
            if(_manifestManager){
                return _manifestManager.bufferedSeconds;
            }
            else{
                return 0;
            }
        }

        public function get bufferedBytesEnd():int{
            return 0;
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
            return _hasEnded;
        }

        public function get seeking():Boolean{
            if(_manifestManager){
                return _manifestManager.isSeeking;
            }
            else{
                return false;
            }
        }

        public function get targetSeekTime():Number{
            if(_targetSeekTime != 0){
                return _targetSeekTime;
            }
            else{
                return 0;
            }
        }

        public function get usesNetStream():Boolean{
            return true;
        }

        public function get metadata():Object{
            return _metadata;
        }

        public function get srcAsString():String{
            if(_src && _src.m3u8 != undefined){
                return _src.m3u8
            }
            else{
                return "";
            }
        }

        public function set src(pSrc:Object):void{
            _src = pSrc;
            if(_isPlaying){
                stop();
                initNetConnection();
            }
        }

        public function init(pSrc:Object, pAutoplay:Boolean):void{
            _src = pSrc;
            _isPaused = false;
            if(pAutoplay){
                initNetConnection();
            }
        }

        public function load():void{

            if(_isPlaying){
                stop();
            }
            _pauseOnStart = true;
            _isPlaying = false;
            _isPaused = true;
            initNetConnection();
        }

        public function play():void{

            if(_isPlaying && !_isPaused){
                return;
            }

            if(_pauseOnStart){
                _pauseOnStart = false;
                _isPaused = false;
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                startAudit();
            }
            else if(_isPaused){
                _isPaused = false;
                resume();
            }
            else if(_src && _src.m3u8 != undefined){
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                initNetConnection();
            }
        }

        public function pause():void{
            _isPaused = true;
            _ns.pause();
            _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
        }

        public function resume():void{
            _isPaused = false;
            _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            if(_pauseOnStart){
                _pauseOnStart = false;
                startAudit();
                _model.broadcastEventExternally(ExternalEventName.ON_START);
            }
            else{
                _ns.resume();
            }
        }

        public function seekBySeconds(pTime:Number):void{

			Console.log("HLSVideoProvider.seekBySeconds(" + pTime + ")");

			if(pTime >= 0){
				_cachedSeekTime = time;
				_targetSeekTime = pTime;
				_isSeeking = true;
				_seekDelayTimer.reset();
				_seekDelayTimer.start();
			}

        }

        public function seekByPercent(pPercent:Number):void{

            if(_manifestManager.totalDuration > 0){
                seekBySeconds(pPercent * _manifestManager.totalDuration);
            }

        }

        public function stop():void{
            if(_isPlaying){
                _netstreamAuditTimer.stop();
                _netstreamAuditTimer.reset();
                _manifestManager.stop();
                _ns.appendBytesAction(NetStreamAppendBytesAction.END_SEQUENCE);
                _ns.close();
                _isPlaying = false;
                _isPaused = false;
                _isSeeking = false;
                _hasEnded = true;
                _streamEndImminent = false;
                _videoReference.clear();
                _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {}));
            }
        }

        public function attachVideo(pVideo:Video):void{
            _videoReference = pVideo;
        }

        public function die():void{
            stop();
        }

        private function initNetConnection():void{
            if(_nc != null){
                _nc.client = {};
                _nc.removeEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
                _nc = null;
            }
            _nc = new NetConnection();
            _nc.client = this;
            _nc.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionStatus);
            _nc.connect(null);
            _streamEndImminent = false;
        }

        private function initNetStream():void{
            if(_ns != null){
                _ns.removeEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
                _ns.client = {};
                _ns = null;
            }
            _ns = new NetStream(_nc);
            _ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);
            _ns.client = this;
            _ns.bufferTime = NETSTREAM_PLAY_BUFFER_START_SIZE;
            _videoReference.attachNetStream(_ns);
            initManifestManager();
        }

        private function initManifestManager():void{
            if(_manifestManager != null){
                _manifestManager.removeEventListener(HLSEvent.FIRST_MANIFEST_LOADED, onFirstManifestLoaded);
                _manifestManager.removeEventListener(HLSEvent.MANIFEST_LOADED, onManifestLoaded);
                _manifestManager.removeEventListener(HLSEvent.FIRST_SEGMENT_LOADED, onFirstSegmentLoaded);
                _manifestManager.removeEventListener(HLSEvent.FIRST_SEEK_SEGMENT_LOADED, onFirstSeekSegmentLoaded);
				_manifestManager = null;
            }
            _manifestManager = new ManifestManager(this);
            _manifestManager.addEventListener(HLSEvent.FIRST_MANIFEST_LOADED, onFirstManifestLoaded);
            _manifestManager.addEventListener(HLSEvent.MANIFEST_LOADED, onManifestLoaded);
            _manifestManager.addEventListener(HLSEvent.FIRST_SEGMENT_LOADED, onFirstSegmentLoaded);
            _manifestManager.addEventListener(HLSEvent.FIRST_SEEK_SEGMENT_LOADED, onFirstSeekSegmentLoaded);
			_manifestManager.manifestURI = _src.m3u8;
            _manifestManager.init();
        }

        private function startAudit():void{
            _netstreamAuditTimer.reset();
            _netstreamAuditTimer.start();
        }

        private function stopAudit():void{
            _netstreamAuditTimer.stop();
            _netstreamAuditTimer.reset();
        }

        // checks to see if we need to get more bytes from the ManifestManager
        private function doAudit():void{
            // if NetStream's buffer is less than half full
            if(_ns.bufferLength / _ns.bufferTime < .5){
				Console.log("HLSVideoProvider: Buffer < 50%!");
                while(_ns.bufferLength / _ns.bufferTime < .5){
                    try{
                        var __data:ByteArray = getNextBytes();
                        if(__data.length == 0){
                            break;
                        }
                        _ns.appendBytes(__data);
                    }
                    catch(error:Error){
                        _model.broadcastErrorEventExternally(error.message);
						Console.log("HLSVideoProvider.doAudit() Error!");
                    }
                }
            }
        }

        // gets the next sequential FLVTag from the ManifestManager
        private function getNextBytes():ByteArray{

            var __data:ByteArray = _manifestManager.getNextData();
            if(__data != null){
                return __data;
            }
            else{
                stopAudit();
                _streamEndImminent = true;
                return _manifestManager.getEndData();
            }
        }

		private function executeSeekBySeconds():void{

			if(_targetSeekTime >= 0){
				// kill the timer
				_seekDelayTimer.stop();
				// stop the manifest manager
				_manifestManager.stop();
				// stop auditing
				stopAudit();
				// clear the buffer
				_ns.seek(0);
				_ns.bufferTime = NETSTREAM_PLAY_BUFFER_START_SIZE;
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

			Console.log("HLSVideoProvider.onNetStreamStatus():"+ e.info.code);

            switch(e.info.code){
                case "NetStream.Play.Start":
                    _hasEnded = false;
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:e.info}));
                    break;

                case "NetStream.Buffer.Full":
                    _isBuffering = false;
					_isSeeking = false;
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                    _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                    _ns.bufferTime = NETSTREAM_PLAY_BUFFER_END_SIZE;

					if (_manifestManager && _manifestManager.isDynamicStream) {
						_manifestManager.readyForAdaptiveSwitching = true;
					}

                    break;

                case "NetStream.Buffer.Empty":
						Console.log('here', _streamEndImminent);

                    if(_streamEndImminent){
                        _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                        stop();
                    }
                    else{
                        _isBuffering = true;
                        _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    }
                    break;

                case "NetStream.Play.Stop":
                    _isPlaying = false;
                    _hasEnded = true;
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {info:e.info}));
                    _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                    break;

                case "NetStream.Seek.Notify":
                    // reset the stream
                    _ns.appendBytesAction(NetStreamAppendBytesAction.RESET_SEEK);
                    // let the player know that we'll need to rebuffer
                    _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                    // grab a segment index for the position we want to seek to
                    var __targetSegmentIndex:int = _manifestManager.getSegmentIndexForPositionInSeconds(_targetSeekTime);
					Console.log("HLSVideoProvider.onNetStreamStatus():NetStream.Seek.Notify:__targetSegmentIndex is "+ __targetSegmentIndex);
                    //if it's valid
                    if(__targetSegmentIndex != -1){
                        // initiate the seek
                        _manifestManager.prepareSeekByStartSegmentIndex(__targetSegmentIndex);
                    }
                    break;

                case "NetStream.Play.StreamNotFound":
                    _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
                    break;

            }
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_NETSTREAM_STATUS, {info:e.info}));
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
            _model.broadcastEventExternally(ExternalEventName.ON_METADATA, _metadata);

        }

        public function onCuePoint(pInfo:Object):void{
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_CUE_POINT, {cuepoint:pInfo}));
        }

        public function onXMPData(pInfo:Object):void{
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_XMP_DATA, {cuepoint:pInfo}));
        }

        public function onPlayStatus(e:Object):void{

        }

        private function onFirstManifestLoaded(e:HLSEvent):void{
            _model.broadcastEventExternally("#HLS# : First Manifest loaded...");
            _manifestManager.start();
        }

        private function onManifestLoaded(e:HLSEvent):void{
            _model.broadcastEventExternally("#HLS# : Manifest loaded...");
        }

        private function onFirstSegmentLoaded(e:HLSEvent):void{
            _ns.play(null);
            _ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
            _ns.appendBytes(_manifestManager.segmentParser.getFlvHeader());
            _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
            _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:{}}));
            _model.broadcastEventExternally("HLSVideoProvider.onFirstSegmentLoaded()");

			_isPlaying = true;
            if(!_pauseOnStart){
                startAudit();
            }
        }

        private function onFirstSeekSegmentLoaded(e:HLSEvent):void{

            //_ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
            //_ns.appendBytes(_manifestManager.segmentParser.getFlvHeader());
            _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:{}}));
            _model.broadcastEventExternally("HLSVideoProvider.onFirstSeekSegmentLoaded()");
            _isPlaying = true;
            startAudit();
        }

		private function onNetStreamAuditTimerTick(e:TimerEvent):void{
            doAudit();
        }

		private function onSeekDelayTimerTick(e:TimerEvent):void{
			executeSeekBySeconds();
		}
    }
}
