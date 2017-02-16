package{

    import com.videojs.VideoJSApp;
    import com.videojs.events.VideoJSEvent;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.Base64;

    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.system.Security;
    import flash.ui.ContextMenu;
    import flash.ui.ContextMenuItem;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.utils.setTimeout;

    [SWF(backgroundColor="#000000", frameRate="60", width="480", height="270")]
    public class VideoJS extends Sprite{

        public const VERSION:String = CONFIG::version;

        private var _app:VideoJSApp;
        private var _stageSizeTimer:Timer;

        public function VideoJS(){
            _stageSizeTimer = new Timer(250);
            _stageSizeTimer.addEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        }

        private function init():void{
            // Allow JS calls from other domains
            Security.allowDomain("*");
            Security.allowInsecureDomain("*");

            if(loaderInfo.hasOwnProperty("uncaughtErrorEvents")){
                // we'll want to suppress ANY uncaught debug errors in production (for the sake of ux)
                // IEventDispatcher(loaderInfo["uncaughtErrorEvents"]).addEventListener("uncaughtError", onUncaughtError);
            }

            if(ExternalInterface.available){
                registerExternalMethods();
            }

            _app = new VideoJSApp();
            addChild(_app);

            _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);

            // add content-menu version info

            var _ctxVersion:ContextMenuItem = new ContextMenuItem("VideoJS Flash Component v" + VERSION, false, false);
            var _ctxAbout:ContextMenuItem = new ContextMenuItem("Copyright © 2014 Brightcove, Inc.", false, false);
            var _ctxMenu:ContextMenu = new ContextMenu();
            _ctxMenu.hideBuiltInItems();
            _ctxMenu.customItems.push(_ctxVersion, _ctxAbout);
            this.contextMenu = _ctxMenu;

        }

        private function registerExternalMethods():void{
            ExternalInterface.marshallExceptions = true;
            try{
                ExternalInterface.addCallback("vjs_appendBuffer", onAppendBufferCalled);
                ExternalInterface.addCallback("vjs_appendChunkReady", onAppendChunkReadyCalled);
                ExternalInterface.addCallback("vjs_echo", onEchoCalled);
                ExternalInterface.addCallback("vjs_endOfStream", onEndOfStreamCalled);
                ExternalInterface.addCallback("vjs_abort", onAbortCalled);
                ExternalInterface.addCallback("vjs_discontinuity", onDiscontinuityCalled);

                ExternalInterface.addCallback("vjs_getProperty", onGetPropertyCalled);
                ExternalInterface.addCallback("vjs_setProperty", onSetPropertyCalled);
                ExternalInterface.addCallback("vjs_autoplay", onAutoplayCalled);
                ExternalInterface.addCallback("vjs_src", onSrcCalled);
                ExternalInterface.addCallback("vjs_load", onLoadCalled);
                ExternalInterface.addCallback("vjs_play", onPlayCalled);
                ExternalInterface.addCallback("vjs_pause", onPauseCalled);
                ExternalInterface.addCallback("vjs_resume", onResumeCalled);
                ExternalInterface.addCallback("vjs_stop", onStopCalled);

                // This callback should only be used when in data generation mode as it
                // will adjust the notion of current time without notifiying the player
                ExternalInterface.addCallback("vjs_adjustCurrentTime", onAdjustCurrentTimeCalled);
            }
            catch(e:SecurityError){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new SecurityError(e.message);
                }
            }
            catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new Error(e.message);
                }
            }
            finally{}



            setTimeout(finish, 50);

        }

        private function finish():void{

            if(loaderInfo.parameters.mode != undefined){
                _app.model.mode = loaderInfo.parameters.mode;
            }

            // Hard coding these in for now until we can come up with a better solution for 5.0 to avoid XSS.
            _app.model.jsEventProxyName = 'videojs.Flash.onEvent';
            _app.model.jsErrorEventProxyName = 'videojs.Flash.onError';

            /*if(loaderInfo.parameters.eventProxyFunction != undefined){
                _app.model.jsEventProxyName = loaderInfo.parameters.eventProxyFunction;
            }

            if(loaderInfo.parameters.errorEventProxyFunction != undefined){
                _app.model.jsErrorEventProxyName = loaderInfo.parameters.errorEventProxyFunction;
            }*/

            if(loaderInfo.parameters.autoplay != undefined && loaderInfo.parameters.autoplay == "true"){
                _app.model.autoplay = true;
            }

            if(loaderInfo.parameters.preload != undefined && loaderInfo.parameters.preload != ""){
                _app.model.preload = String(loaderInfo.parameters.preload);
            }

            if(loaderInfo.parameters.muted != undefined && loaderInfo.parameters.muted == "true"){
                _app.model.muted = true;
            }

            if(loaderInfo.parameters.loop != undefined && loaderInfo.parameters.loop == "true"){
                _app.model.loop = true;
            }

            if(loaderInfo.parameters.src != undefined && loaderInfo.parameters.src != ""){
              if (isExternalMSObjectURL(loaderInfo.parameters.src)) {
                _app.model.srcFromFlashvars = null;
                openExternalMSObject(loaderInfo.parameters.src);
              } else {
                _app.model.srcFromFlashvars = String(loaderInfo.parameters.src);
              }
            } else{
              if(loaderInfo.parameters.rtmpConnection != undefined && loaderInfo.parameters.rtmpConnection != ""){
                _app.model.rtmpConnectionURL = loaderInfo.parameters.rtmpConnection;
              }

              if(loaderInfo.parameters.rtmpStream != undefined && loaderInfo.parameters.rtmpStream != ""){
                _app.model.rtmpStream = loaderInfo.parameters.rtmpStream;
              }
            }

            // Hard coding this in for now until we can come up with a better solution for 5.0 to avoid XSS.
            ExternalInterface.call('videojs.Flash.onReady', ExternalInterface.objectID);

            /*if(loaderInfo.parameters.readyFunction != undefined){
              try{
                ExternalInterface.call(_app.model.cleanEIString(loaderInfo.parameters.readyFunction), ExternalInterface.objectID);
              }
              catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                  throw new Error(e.message);
                }
              }
            }*/
        }

        private function onAddedToStage(e:Event):void{
            stage.addEventListener(MouseEvent.CLICK, onStageClick);
            stage.addEventListener(Event.RESIZE, onStageResize);
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            _stageSizeTimer.start();
        }

        private function onStageSizeTimerTick(e:TimerEvent):void{
            if(stage.stageWidth > 0 && stage.stageHeight > 0){
                _stageSizeTimer.stop();
                _stageSizeTimer.removeEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
                init();
            }
        }

        private function onStageResize(e:Event):void{
            if(_app != null){
                _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
                _app.model.broadcastEvent(new VideoJSEvent(VideoJSEvent.STAGE_RESIZE, {}));
            }
        }

        private function onAppendBufferCalled(base64str:String):void{
            var bytes:ByteArray = Base64.decode(base64str);
            // write the bytes to the provider
            _app.model.appendBuffer(bytes);
        }

        private function onAppendChunkReadyCalled(fnName:String):void{
            var bytes:ByteArray = Base64.decode(ExternalInterface.call(fnName));

            // write the bytes to the provider
            _app.model.appendBuffer(bytes);
        }

        private function onAdjustCurrentTimeCalled(pValue:Number):void {
            _app.model.adjustCurrentTime(pValue);
        }

        private function onEchoCalled(pResponse:* = null):*{
            return pResponse;
        }

        private function onEndOfStreamCalled():*{
            _app.model.endOfStream();
        }

        private function onAbortCalled():*{
            _app.model.abort();
        }

        private function onDiscontinuityCalled():*{
            _app.model.discontinuity();
        }

        private function onGetPropertyCalled(pPropertyName:String = ""):*{

            switch(pPropertyName){
                case "mode":
                    return _app.model.mode;
                case "autoplay":
                    return _app.model.autoplay;
                case "loop":
                    return _app.model.loop;
                case "preload":
                    return _app.model.preload;
                    break;
                case "metadata":
                    return _app.model.metadata;
                    break;
                case "duration":
                    return _app.model.duration;
                    break;
                case "eventProxyFunction":
                    return _app.model.jsEventProxyName;
                    break;
                case "errorEventProxyFunction":
                    return _app.model.jsErrorEventProxyName;
                    break;
                case "currentSrc":
                    return _app.model.src;
                    break;
                case "currentTime":
                    return _app.model.time;
                    break;
                case "time":
                    return _app.model.time;
                    break;
                case "initialTime":
                    return 0;
                    break;
                case "defaultPlaybackRate":
                    return 1;
                    break;
                case "ended":
                    return _app.model.hasEnded;
                    break;
                case "volume":
                    return _app.model.volume;
                    break;
                case "muted":
                    return _app.model.muted;
                    break;
                case "paused":
                    return _app.model.paused;
                    break;
                case "seeking":
                    return _app.model.seeking;
                    break;
                case "networkState":
                    return _app.model.networkState;
                    break;
                case "readyState":
                    return _app.model.readyState;
                    break;
                case "buffered":
                    return _app.model.buffered;
                    break;
                case "bufferedBytesStart":
                    return 0;
                    break;
                case "bufferedBytesEnd":
                    return _app.model.bufferedBytesEnd;
                    break;
                case "bytesTotal":
                    return _app.model.bytesTotal;
                    break;
                case "videoWidth":
                    return _app.model.videoWidth;
                    break;
                case "videoHeight":
                    return _app.model.videoHeight;
                    break;
                case "rtmpConnection":
                    return _app.model.rtmpConnectionURL;
                    break;
                case "rtmpStream":
                    return _app.model.rtmpStream;
                    break;
            }
            return null;
        }

        private function onSetPropertyCalled(pPropertyName:String = "", pValue:* = null):void{
            switch(pPropertyName){
                case "duration":
                    _app.model.duration = Number(pValue);
                    break;
                case "mode":
                    _app.model.mode = String(pValue);
                    break;
                case "loop":
                    _app.model.loop = _app.model.humanToBoolean(pValue);
                    break;
                case "background":
                    _app.model.backgroundColor = _app.model.hexToNumber(String(pValue));
                    _app.model.backgroundAlpha = 1;
                    break;
                case "eventProxyFunction":
                    _app.model.jsEventProxyName = String(pValue);
                    break;
                case "errorEventProxyFunction":
                    _app.model.jsErrorEventProxyName = String(pValue);
                    break;
                case "autoplay":
                    _app.model.autoplay = _app.model.humanToBoolean(pValue);
                    if (_app.model.autoplay) {
                        _app.model.preload = "auto";
                    }
                    break;
                case "preload":
                    _app.model.preload = String(pValue);
                    break;
                case "src":
                    // same as when vjs_src() is called directly
                    onSrcCalled(pValue);
                    break;
                case "currentTime":
                    _app.model.seekBySeconds(Number(pValue));
                    break;
                case "currentPercent":
                    _app.model.seekByPercent(Number(pValue));
                    break;
                case "muted":
                    _app.model.muted = _app.model.humanToBoolean(pValue);
                    break;
                case "volume":
                    _app.model.volume = Number(pValue);
                    break;
                case "rtmpConnection":
                    _app.model.rtmpConnectionURL = String(pValue);
                    break;
                case "rtmpStream":
                    _app.model.rtmpStream = String(pValue);
                    break;
                default:
                    _app.model.broadcastErrorEventExternally(ExternalErrorEventName.PROPERTY_NOT_FOUND, pPropertyName);
                    break;
            }
        }

        private function onAutoplayCalled(pAutoplay:* = false):void{
          _app.model.autoplay = _app.model.humanToBoolean(pAutoplay);
        }

        private function isExternalMSObjectURL(pSrc:*):Boolean{
          return pSrc.indexOf('blob:vjs-media-source/') === 0;
        }

        private function openExternalMSObject(pSrc:*):void{
          var cleanSrc:String
          if (/^blob:vjs-media-source\/\d+$/.test(pSrc)) {
            cleanSrc = pSrc;
          } else {
            cleanSrc = _app.model.cleanEIString(pSrc);
          }
          ExternalInterface.call('videojs.MediaSource.open', cleanSrc, ExternalInterface.objectID);
        }

        private function onSrcCalled(pSrc:* = ""):void{
          // check if an external media source object will provide the video data
          if (isExternalMSObjectURL(pSrc)) {
            // null is passed to the netstream which enables appendBytes mode
            _app.model.src = null;
            // open the media source object for creating a source buffer
            // and provide a reference to this swf for passing data from the soure buffer
            openExternalMSObject(pSrc);

            // ExternalInterface.call('videojs.MediaSource.sourceBufferUrls["' + pSrc + '"]', ExternalInterface.objectID);
          } else {
            _app.model.src = String(pSrc);
          }
        }

        private function onLoadCalled():void{
            _app.model.load();
        }

        private function onPlayCalled():void{
            _app.model.play();
        }

        private function onPauseCalled():void{
            _app.model.pause();
        }

        private function onResumeCalled():void{
            _app.model.resume();
        }

        private function onStopCalled():void{
            _app.model.stop();
        }

        private function onUncaughtError(e:Event):void{
            e.preventDefault();
        }

        private function onStageClick(e:MouseEvent):void{
            _app.model.broadcastEventExternally(ExternalEventName.ON_STAGE_CLICK);
        }

    }
}
