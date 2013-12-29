package com.videojs{
    
    import com.videojs.events.VideoJSEvent;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalErrorEventName;
    
    import flash.display.Bitmap;
    import flash.display.Loader;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.Video;
    import flash.net.URLRequest;
    import flash.system.LoaderContext;
    
    public class VideoJSView extends Sprite{
        
        private var _uiVideo:Video;
        private var _uiPosterContainer:Sprite;
            private var _uiPosterImage:Loader;
        private var _uiBackground:Sprite;
        
        private var _model:VideoJSModel;
        
        public function VideoJSView(){
            
            _model = VideoJSModel.getInstance();
            _model.addEventListener(VideoJSEvent.POSTER_SET, onPosterSet);
            _model.addEventListener(VideoJSEvent.BACKGROUND_COLOR_SET, onBackgroundColorSet);
            _model.addEventListener(VideoJSEvent.STAGE_RESIZE, onStageResize);
            _model.addEventListener(VideoPlaybackEvent.ON_STREAM_START, onStreamStart);
            _model.addEventListener(VideoPlaybackEvent.ON_META_DATA, onMetaData);
            _model.addEventListener(VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE, onDimensionUpdate);
            
            _uiBackground = new Sprite();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
            _uiBackground.alpha = _model.backgroundAlpha;
            addChild(_uiBackground);
            
            _uiPosterContainer = new Sprite();
            
                _uiPosterImage = new Loader();
                _uiPosterImage.visible = false;
                _uiPosterContainer.addChild(_uiPosterImage);
            
            addChild(_uiPosterContainer);
            
            _uiVideo = new Video();
            _uiVideo.width = _model.stageRect.width;
            _uiVideo.height = _model.stageRect.height;
            _uiVideo.smoothing = true;
            addChild(_uiVideo);
            
            _model.videoReference = _uiVideo;
            
        }
        
        /**
         * Loads the poster frame, if one has been specified. 
         * 
         */        
        private function loadPoster():void{
            if(_model.poster != ""){
                if(_uiPosterImage != null){
                    _uiPosterImage.contentLoaderInfo.removeEventListener(Event.COMPLETE, onPosterLoadComplete);
                    _uiPosterImage.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onPosterLoadError);
                    _uiPosterImage.contentLoaderInfo.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onPosterLoadSecurityError);
                    _uiPosterImage.parent.removeChild(_uiPosterImage);
                    _uiPosterImage = null;
                }
                var __request:URLRequest = new URLRequest(_model.poster);
                _uiPosterImage = new Loader();
                _uiPosterImage.visible = false;
                var __context:LoaderContext = new LoaderContext();
                //__context.checkPolicyFile = true;
                _uiPosterImage.contentLoaderInfo.addEventListener(Event.COMPLETE, onPosterLoadComplete);
                _uiPosterImage.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onPosterLoadError);
                _uiPosterImage.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onPosterLoadSecurityError);
                try{
                    _uiPosterImage.load(__request, __context);
                }
                catch(e:Error){
                    
                }
            }
        }

        private function sizeVideoObject():void{
            
            var __targetWidth:int, __targetHeight:int;
            
            var __availableWidth:int = _model.stageRect.width;
            var __availableHeight:int = _model.stageRect.height;
            
            var __nativeWidth:int = 100;
            
            if(_model.metadata.width != undefined){
                __nativeWidth = Number(_model.metadata.width);
            }
            
            if(_uiVideo.videoWidth != 0){
                __nativeWidth = _uiVideo.videoWidth;
            }
            
            var __nativeHeight:int = 100;
            
            if(_model.metadata.width != undefined){
                __nativeHeight = Number(_model.metadata.height);
            }
            
            if(_uiVideo.videoWidth != 0){
                __nativeHeight = _uiVideo.videoHeight;
            }

            // first, size the whole thing down based on the available width
            __targetWidth = __availableWidth;
            __targetHeight = __targetWidth * (__nativeHeight / __nativeWidth);
            
            if(__targetHeight > __availableHeight){
                __targetWidth = __targetWidth * (__availableHeight / __targetHeight);
                __targetHeight = __availableHeight;
            }

            _uiVideo.width = __targetWidth;
            _uiVideo.height = __targetHeight;
            
            _uiVideo.x = Math.round((_model.stageRect.width - _uiVideo.width) / 2);
            _uiVideo.y = Math.round((_model.stageRect.height - _uiVideo.height) / 2);
            

        }

        private function sizePoster():void{

            // wrap this stuff in a try block to avoid freezing the call stack on an image
            // asset that loaded successfully, but doesn't have an associated crossdomain
            // policy : /
            try{
                // only do this stuff if there's a loaded poster to operate on
                if(_uiPosterImage.content != null){
    
                    var __targetWidth:int, __targetHeight:int;
                
                    var __availableWidth:int = _model.stageRect.width;
                    var __availableHeight:int = _model.stageRect.height;
            
                    var __nativeWidth:int = _uiPosterImage.content.width;
                    var __nativeHeight:int = _uiPosterImage.content.height;

                    // first, size the whole thing down based on the available width
                    __targetWidth = __availableWidth;
                    __targetHeight = __targetWidth * (__nativeHeight / __nativeWidth);
            
                    if(__targetHeight > __availableHeight){
                        __targetWidth = __targetWidth * (__availableHeight / __targetHeight);
                        __targetHeight = __availableHeight;
                    }
            
            
                    _uiPosterImage.width = __targetWidth;
                    _uiPosterImage.height = __targetHeight;
            
                    _uiPosterImage.x = Math.round((_model.stageRect.width - _uiPosterImage.width) / 2);
                    _uiPosterImage.y = Math.round((_model.stageRect.height - _uiPosterImage.height) / 2);
                }
            }
            catch(e:Error){
                
            }
        }

        private function onBackgroundColorSet(e:VideoPlaybackEvent):void{
            _uiBackground.graphics.clear();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
        }
        
        private function onStageResize(e:VideoJSEvent):void{
            
            _uiBackground.graphics.clear();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
            sizePoster();
            sizeVideoObject();
        }
        
        private function onPosterSet(e:VideoJSEvent):void{
            loadPoster();
        }
        
        private function onPosterLoadComplete(e:Event):void{
            
            // turning smoothing on for assets that haven't cleared the security sandbox / crossdomain hurdle
            // will result in the call stack freezing, so we need to wrap access to Loader.content
            try{
                (_uiPosterImage.content as Bitmap).smoothing = true;
            }
            catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new Error(e.message);
                }
            }
            _uiPosterContainer.addChild(_uiPosterImage);
            sizePoster();
            if(!_model.playing){
                _uiPosterImage.visible = true;
            }
            
        }
        
        private function onPosterLoadError(e:IOErrorEvent):void{
            _model.broadcastErrorEventExternally(ExternalErrorEventName.POSTER_IO_ERROR, e.text);
        }
        
        private function onPosterLoadSecurityError(e:SecurityErrorEvent):void{
            _model.broadcastErrorEventExternally(ExternalErrorEventName.POSTER_SECURITY_ERROR, e.text);
        }
        
        private function onStreamStart(e:VideoPlaybackEvent):void{
            _uiPosterImage.visible = false;
        }
        
        private function onMetaData(e:VideoPlaybackEvent):void{        
            sizeVideoObject();
        }

        private function onDimensionUpdate(e:VideoPlaybackEvent):void{
            sizeVideoObject();
        }
        
    }
}