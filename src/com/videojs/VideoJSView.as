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
    import flash.events.StageVideoEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.Video;
    import flash.media.StageVideo;
    import flash.net.NetStream;
    import flash.net.URLRequest;
    import flash.system.LoaderContext;

    public class VideoJSView extends Sprite{

        private var _uiVideo:Video;
        private var _stageVideo:StageVideo;
        private var _uiBackground:Sprite;
        private var _model:VideoJSModel;

        public function VideoJSView(){

            _model = VideoJSModel.getInstance();
            _model.addEventListener(VideoJSEvent.BACKGROUND_COLOR_SET, onBackgroundColorSet);
            _model.addEventListener(VideoJSEvent.STAGE_RESIZE, onStageResize);
            _model.addEventListener(VideoPlaybackEvent.ON_META_DATA, onMetaData);
            _model.addEventListener(VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE, onDimensionUpdate);
            _model.addEventListener(VideoPlaybackEvent.ON_STREAM_READY,onStreamReady);
            _uiBackground = new Sprite();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
            _uiBackground.alpha = _model.backgroundAlpha;
            addChild(_uiBackground);

            _uiVideo = new Video();
            _uiVideo.width = _model.stageRect.width;
            _uiVideo.height = _model.stageRect.height;
            _uiVideo.smoothing = true;
            addChild(_uiVideo);

            _model.videoReference = _uiVideo;
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

            if(_model.stageVideoInUse){
              _stageVideo.viewPort = _model.stageRect;
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
            sizeVideoObject();
        }

        private function onMetaData(e:VideoPlaybackEvent):void{
            sizeVideoObject();
        }

        private function onDimensionUpdate(e:VideoPlaybackEvent):void{
            sizeVideoObject();
        }

        private function onStreamReady(e:VideoPlaybackEvent):void{
            toggleStageVideo(e.data.ns);
        }

        private function toggleStageVideo(ns:NetStream):void
        {
            // If we choose StageVideo we attach the NetStream to StageVideo
            if (_model.stageVideoAvailable)
            {
                // Try to render as stage video
                var v:Vector.<StageVideo> = stage.stageVideos;
                if ( v.length >= 1 ) {
                    _model.stageVideoInUse = true;
                    _stageVideo = v[0];
                    _stageVideo.viewPort =_model.stageRect;
                    _stageVideo.attachNetStream(ns);
                    // If we use StageVideo, we just remove from the display list the Video object to avoid covering the StageVideo object (always in the background)
                    if(this.contains(_uiVideo)){
                        removeChild (_uiVideo);
                        removeChild (_uiBackground);
                    }
                }

            }
            else
            {
                // Otherwise we attach it to a Video object
                _model.stageVideoInUse = false;
                if(!this.contains(_uiVideo)) {
                    addChild(_uiVideo);
                    addChild(_uiBackground);
                }
            }
        }

    }
}
