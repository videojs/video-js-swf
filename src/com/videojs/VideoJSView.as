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
    import flash.events.VideoEvent;
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


        private function sizeStageVideoObject():void{
            if(_model.stageVideoInUse){
                var videoY:Number=0;
                var videoX:Number=0;
                var videoWidth:Number=0;
                var videoHeight:Number=0;
                var orig_width:Number = _model.metadata.width;
                var orig_height:Number = _model.metadata.height;
                var aspect:Number = orig_width/orig_height;
                var containerWidth:Number=_model.stageRect.width;
                var containerHeight:Number=_model.stageRect.height;
                var containerAspect:Number = containerWidth/containerHeight;

                if ((aspect > containerAspect) && ((aspect-containerAspect)/containerAspect > 0.107)) {
                    // trace("film aspect is wider by more than 10%");
                    // the film has a wider aspect ration than the container by more than 10.7%. Let's take the container's width as the video's width (possible letter box)
                    videoWidth = containerWidth;
                    // now set the height based on the original ratio
                    videoHeight = videoWidth/aspect;
                }

                if ((aspect < containerAspect) && ((containerAspect-aspect)/aspect > 0.107)) {
                    // trace("film is heigher by more than 10%");
                    // the film has a heigher aspect ration than the container. Let's take the container's height as the video's width (possible pill box)
                    videoHeight = containerHeight;
                    // now set the height based on the original ratio
                    videoWidth = videoHeight*aspect;
                }

                if ( (aspect == containerAspect) || ( (aspect > containerAspect) && ( (aspect-containerAspect)/containerAspect <= 0.107) ) ||  ( (aspect < containerAspect) && ((containerAspect-aspect)/aspect <= 0.107) ) )
                {
                    // trace("video and container have essentially the same aspect ratio");
                    // the video and container have the same aspect ratio, or are at least within 10% of eachother
                    videoWidth = containerWidth;
                    videoHeight = containerHeight;
                }

                if (videoWidth ===0 || videoHeight ===0){
                    return;
                }

                if (containerWidth-videoWidth >0)
                // container is wider, we need a pill box -> center video in x axis
                {
                    // trace("we need to pill box this thing");
                    videoX = ((containerWidth-videoWidth)/2);
                    videoY = 0;
                }

                if (containerHeight-videoHeight > 0)
                {
                    // trace("we need to letter box this thing");
                    // container is higher, we need a letter box -> center video in y axis
                    videoY = ((containerHeight-videoHeight)/2);
                    videoX = 0;
                }
                if (containerWidth == videoWidth && containerHeight == videoHeight) {
                    videoX = 0;
                    videoY = 0;
                }
                // close onMetaData

                var stageVideoRatio=  new Rectangle(videoX,videoY,videoWidth,videoHeight);
                _stageVideo.viewPort = stageVideoRatio;
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
            sizeStageVideoObject();
        }

        private function onMetaData(e:VideoPlaybackEvent):void{
            sizeVideoObject();
            sizeStageVideoObject();
        }

        private function onDimensionUpdate(e:VideoPlaybackEvent):void{
            sizeVideoObject();
        }

        private function onStreamReady(e:VideoPlaybackEvent):void{
            toggleStageVideo(e.data.ns);
        }

        private function onRenderStateChanged(p_event:Event):void
        {
            switch(StageVideoEvent(p_event).status)
            {
                case VideoEvent.RENDER_STATUS_UNAVAILABLE:
                    toggleStageVideo(null);
                    break;
            }
        }

        private function toggleStageVideo(ns:NetStream = null):void
        {
            // If we choose StageVideo we attach the NetStream to StageVideo
            if (ns && _model.stageVideoAvailable && this.stage)
            {
                // Try to render as stage video
                var v:Vector.<StageVideo> = this.stage.stageVideos;
                if ( v.length >= 1 ) {
                    _model.stageVideoInUse = true;
                    _stageVideo = v[0];
                    _stageVideo.addEventListener(StageVideoEvent.RENDER_STATE, this.onRenderStateChanged);
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
                if(_stageVideo){
                    _stageVideo.attachNetStream(null);
                }
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
