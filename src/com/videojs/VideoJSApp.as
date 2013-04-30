package com.videojs{
    
    import flash.display.Sprite;
	
    public class VideoJSApp extends Sprite{
        
        private var _uiView:VideoJSView;
        private var _model:VideoJSModel;
        
        public function VideoJSApp(){
            
            _model = VideoJSModel.getInstance()

            _uiView = new VideoJSView();
            addChild(_uiView);

        }
        
        public function get model():VideoJSModel{
            return _model;
        }
        
    }
}