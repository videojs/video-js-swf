package com.videojs.providers.hls.events{

    import flash.events.Event;

    public class HLSErrorEvent extends Event{

        public static const INVALID_MANIFEST:String = "HLSErrorEvent.INVALID_MANIFEST";
		public static const INVALID_PLAYLIST:String = "HLSErrorEvent.INVALID_PLAYLIST";

		public static const MEDIA_SEQUENCE_EMPTY:String = "HLSErrorEvent.MEDIA_SEQUENCE_EMPTY";
		public static const MEDIA_SEQUENCE_NAN:String = "HLSErrorEvent.MEDIA_SEQUENCE_NAN";

		public static const TARGET_DURATION_EMPTY:String = "HLSErrorEvent.TARGET_DURATION_EMPTY";
		public static const TARGET_DURATION_NAN:String = "HLSErrorEvent.TARGET_DURATION_NAN";
		public static const TARGET_DURATION_INVALID:String = "HLSErrorEvent.TARGET_DURATION_INVALID";

		public static const ZEN_TOTAL_DURATION_EMPTY:String = "HLSErrorEvent.ZEN_TOTAL_DURATION_EMPTY";
		public static const ZEN_TOTAL_DURATION_NAN:String = "HLSErrorEvent.ZEN_TOTAL_DURATION_NAN";

		public static const TOTAL_DURATION_INVALID:String = "HLSErrorEvent.TOTAL_DURATION_INVALID";

		public static const ENDLIST_ALREADY_ENCOUNTERED:String = "HLSErrorEvent.ENDLIST_ALREADY_ENCOUNTERED";
		public static const ENDLIST_NOT_LAST_LINE:String = "HLSErrorEvent.ENDLIST_NOT_LAST_LINE";

		public static const TS_SYNC_BYTE_MISSING:String = "HLSErrorEvent.TS_SYNC_BYTE_MISSING";

		public static const SEGMENT_INF_EMPTY:String = "HLSErrorEvent.SEGMENT_INF_EMPTY";
		public static const SEGMENT_INF_NAN:String = "HLSErrorEvent.SEGMENT_INF_NAN";
		public static const SEGMENT_INF_GREATER_THAN_TARGET:String = "HLSErrorEvent.SEGMENT_INF_GREATER_THAN_TARGET";

		public static const SEGMENT_MISSING:String = "HLSErrorEvent.SEGMENT_MISSING";
		public static const SEGMENT_DOWNLOAD_ERROR:String = "HLSErrorEvent.SEGMENT_DOWNLOAD_ERROR"

        public static const MANIFEST_LOAD_SECURITY_ERROR:String = "HLSErrorEvent.MANIFEST_LOAD_SECURITY_ERROR";

        // a flexible container object for whatever data needs to be attached to any of these events
        private var _data:Object;

        public function HLSErrorEvent(pType:String, pData:Object = null){
            super(pType, true, false);
            _data = pData;
        }

        public function get data():Object {
            return _data;
        }

    }
}
