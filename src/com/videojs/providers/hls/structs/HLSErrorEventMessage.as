package com.videojs.providers.hls.structs {

	public class HLSErrorEventMessage {
		public static const MANIFEST_INVALID:String = "Manifest Parse Error: Invalid Manifest: (invalid value) was specified for ext-x-m3u";
		public static const PLAYLIST_INVALID:String = "Manifest Parse Error: Invalid Playlist Type: (invalid value) was specified for ext-x-playlist-type";
		public static const PLAYLIST_EMPTY:String = "Manifest Parse Error: Empty Media Sequence";

		public static const SEGMENT_MISSING:String = "Segment missing/404";
		public static const SEGMENT_DOWNLOAD_ERROR:String = "Segment server error/500";


		public static const MEDIA_SEQUENCE_EMPTY:String = "Manifest Parse Error: Empty Media Sequence";
		public static const MEDIA_SEQUENCE_NAN:String = "Manifest Parse Error: Media Sequence is not a Number";
		public static const MEDIA_SEQUENCE_INVALID:String = "Manifest Parse Error: Media Sequence Invalid";

		public static const TARGET_DURATION_EMPTY:String = "Manifest Parse Error: TARGET Duration Empty";
		public static const TARGET_DURATION_NAN:String = "Manifest Parse Error: TARGET Duration is not a Number";
		public static const TARGET_DURATION_INVALID:String = "Manifest Parse Error: TARGET Duration Invalid";

		public static const SEGMENT_INF_EMPTY:String = "Manifest Parse Error: Segment INF Empty";
		public static const SEGMENT_INF_NAN:String = "Manifest Parse Error: Segment INF value parsed was not a number";
		public static const SEGMENT_INF_GREATER_THAN_TARGET:String = "Manifest Parse Error: Segment INF was greater than Target Duration value";


		public static const ZEN_TOTAL_DURATION_EMPTY:String = "Manifest Parse Error: Zen Total Duration Empty";
		public static const ZEN_TOTAL_DURATION_NAN:String = "Manifest Parse Error: Zen Total Duration is not a Number";

		public static const TOTAL_DURATION_INVALID:String = "Manifest Parse Error: Total Duration Invalid";

		public static const ENDLIST_ALREADY_ENCOUNTERED:String = "Manifest Parse Error: ENDLIST tag encountered multiple times";
		public static const ENDLIST_NOT_LAST_LINE:String = "Manifest Parse Error: ENDLIST tag encountered before the last line of manifest";

	}

}
