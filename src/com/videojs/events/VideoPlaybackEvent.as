package com.videojs.events{

    import flash.events.Event;

    public class VideoPlaybackEvent extends Event{

        public static const ON_CUE_POINT:String = "VideoPlaybackEvent.ON_CUE_POINT";
        public static const ON_META_DATA:String = "VideoPlaybackEvent.ON_META_DATA";
        public static const ON_XMP_DATA:String = "VideoPlaybackEvent.ON_XMP_DATA";
        public static const ON_NETSTREAM_STATUS:String = "VideoPlaybackEvent.ON_NETSTREAM_STATUS";
        public static const ON_NETCONNECTION_STATUS:String = "VideoPlaybackEvent.ON_NETCONNECTION_STATUS";
        public static const ON_STREAM_READY:String = "VideoPlaybackEvent.ON_STREAM_READY";
        public static const ON_STREAM_NOT_READY:String = "VideoPlaybackEvent.ON_STREAM_NOT_READY";
        public static const ON_STREAM_START:String = "VideoPlaybackEvent.ON_STREAM_START";
        public static const ON_STREAM_CLOSE:String = "VideoPlaybackEvent.ON_STREAM_CLOSE";
        public static const ON_STREAM_METRICS_UPDATE:String = "VideoPlaybackEvent.ON_STREAM_METRICS_UPDATE";
        public static const ON_STREAM_PAUSE:String = "VideoPlaybackEvent.ON_STREAM_PAUSE";
        public static const ON_STREAM_RESUME:String = "VideoPlaybackEvent.ON_STREAM_RESUME";
        public static const ON_STREAM_SEEK_COMPLETE:String = "VideoPlaybackEvent.ON_STREAM_SEEK_COMPLETE";
        public static const ON_STREAM_REBUFFER_START:String = "VideoPlaybackEvent.ON_STREAM_REBUFFER_START";
        public static const ON_STREAM_REBUFFER_END:String = "VideoPlaybackEvent.ON_STREAM_REBUFFER_END";
        public static const ON_ERROR:String = "VideoPlaybackEvent.ON_ERROR";
        public static const ON_UPDATE:String = "VideoPlaybackEvent.ON_UPDATE";
        public static const ON_VIDEO_DIMENSION_UPDATE:String = "VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE";
        public static const ON_TEXT_DATA:String = "VideoPlaybackEvent.ON_TEXT_DATA";

        // a flexible container object for whatever data needs to be attached to any of these events
        private var _data:Object;

        public function VideoPlaybackEvent(pType:String, pData:Object = null){
            super(pType, true, false);
            _data = pData;
        }

        public function get data():Object {
            return _data;
        }

    }
}
