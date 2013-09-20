package com.videojs.providers.hls.events{

    import flash.events.Event;

    public class HLSEvent extends Event{

        public static const FIRST_MANIFEST_LOADED:String = "HLSEvent.FIRST_MANIFEST_LOADED";
        public static const MANIFEST_LOADED:String = "HLSEvent.MANIFEST_LOADED";
        public static const FIRST_SEGMENT_LOADED:String = "HLSEvent.FIRST_SEGMENT_LOADED";
        public static const FIRST_SEEK_SEGMENT_LOADED:String = "HLSEvent.FIRST_SEEK_SEGMENT_LOADED";
        public static const LAST_SEGMENT_LOADED:String = "HLSEvent.LAST_SEGMENT_LOADED";
        public static const SEGMENT_LOADED:String = "HLSEvent.SEGMENT_LOADED";
        public static const ADDITIONAL_DATA_AVAILABLE:String = "HLSEvent.ADDITIONAL_DATA_AVAILABLE";
        public static const ADDITIONAL_DATA_UNAVAILABLE:String = "HLSEvent.ADDITIONAL_DATA_UNAVAILABLE";

        // Rendition Switching Events
        public static const SWITCH_START:String = "HLSEvent.SWITCH_START";
        public static const SWITCH_END:String = "HLSEvent.SWITCH_END";
        public static const RENDITION_SELECTED:String = "HLSEvent.RENDITION_SELECTED";
		public static const DYNAMIC_STREAM_CHANGE:String = "HLSEvent.DYNAMIC_STREAM_CHANGE";

        // a flexible container object for whatever data needs to be attached to any of these events
        private var _data:Object;

        public function HLSEvent(pType:String, pData:Object = null){
            super(pType, true, false);
            _data = pData;
        }

        public function get data():Object {
            return _data;
        }

    }
}
