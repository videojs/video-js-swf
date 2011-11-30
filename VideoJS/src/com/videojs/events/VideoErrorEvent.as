package com.videojs.events{
    
    import flash.events.Event;
    
    public class VideoErrorEvent extends Event{
        
        public static const SRC_MISSING:String = "VideoPlaybackEvent.SRC_MISSING";
        
        // a flexible container object for whatever data needs to be attached to any of these events
        private var _data:Object;
        
        public function VideoErrorEvent(pType:String, pData:Object = null){
            super(pType, true, false);
            _data = pData;
        }
        
        public function get data():Object {
            return _data;
        }
        
    }
}