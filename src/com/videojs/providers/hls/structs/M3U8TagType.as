package com.videojs.providers.hls.structs{
    
    /*
     * Derived from V8: http://tools.ietf.org/html/draft-pantos-http-live-streaming-08
     */
    
    public class M3U8TagType{

        
        /**
         *  Identifies manifest as Extended M3U - must be present on first line!
         */ 
        public static const EXTM3U:String = "#EXTM3U";

        /**
         *  Specifies duration.
         *  Syntax:  #EXTINF:<duration>,<title>
         *  Example: #EXTINF:10,
         */        
        public static const EXTINF:String = "#EXTINF:";

        /**
         *  Indicates that a media segment is a sub-range of the resource identified by its media URI.
         *  Syntax:  #EXT-X-BYTERANGE:<n>[@o]
         */    
        public static const BYTERANGE:String = "#EXT-X-BYTERANGE:";
        
        /**
         *  Specifies the maximum media segment duration - applies to entire manifest.
         *  Syntax:  #EXT-X-TARGETDURATION:<s>
         *  Example: #EXT-X-TARGETDURATION:10
         */ 
        public static const TARGETDURATION:String = "#EXT-X-TARGETDURATION:";
        
        /**
         *  Specifies the sequence number of the first URI in a manifest.
         *  Syntax:  #EXT-X-MEDIA-SEQUENCE:<i>
         *  Example: #EXT-X-MEDIA-SEQUENCE:50
         */ 
        public static const MEDIA_SEQUENCE:String = "#EXT-X-MEDIA-SEQUENCE:";
        
        /**
         *  Specifies a method by which media segments can be decrypted, if encryption is present.
         *  Syntax:  #EXT-X-KEY:<attribute-list>
         *  Note: This is likely irrelevant in the context of the Flash Player.
         */ 
        public static const KEY:String = "#EXT-X-KEY:";
        
        /**
         *  Associates the first sample of a media segment with an absolute date and/or time.  Applies only to the next media URI.
         *  Syntax:  #EXT-X-PROGRAM-DATE-TIME:<YYYY-MM-DDThh:mm:ssZ>
         *  Example: #EXT-X-PROGRAM-DATE-TIME:2010-02-19T14:54:23.031+08:00
         */ 
        public static const PROGRAM_DATE_TIME:String = "#EXT-X-PROGRAM-DATE-TIME:";
        
        /**
         *  Indicates whether the client MAY or MUST NOT cache downloaded media segments for later replay.
         *  Syntax:  #EXT-X-ALLOW-CACHE:<YES|NO>
         *  Note: This is likely irrelevant in the context of the Flash Player.
         */ 
        public static const ALLOW_CACHE:String = "#EXT-X-ALLOW_CACHE:";
        
        /**
         *  Provides mutability information about the manifest.
         *  Syntax:  #EXT-X-PLAYLIST-TYPE:<EVENT|VOD>
         */
        public static const PLAYLIST_TYPE:String = "#EXT-X-PLAYLIST-TYPE:";
        
        /**
         *  Indicates that no more media segments will be added to the manifest. May occur ONCE, anywhere in the mainfest file.
         */
        public static const ENDLIST:String = "#EXT-X-ENDLIST";
        
        /**
         *  Used to relate Playlists that contain alternative renditions of the same content.
         *  Syntax:  #EXT-X-MEDIA:<attribute-list>
         */
        public static const MEDIA:String = "#EXT-X-MEDIA:";
        
        /**
         *  Identifies a media URI as a Playlist file containing a multimedia presentation and provides information about that presentation.
         *  Syntax:  #EXT-X-STREAM-INF:<attribute-list>
         *           <URI>
         */
        public static const STREAM_INF:String = "#EXT-X-STREAM-INF:";
        
        /**
         *  Indicates an encoding discontinuity between the media segment that follows it and the one that preceded it.
         */
        public static const DISCONTINUITY:String = "#EXT-X-DISCONTINUITY";
        
        /**
         *  Indicates that each media segment in the manifest describes a single I-frame.
         */
        public static const I_FRAMES_ONLY:String = "#EXT-X-I-FRAMES-ONLY";
        
        /**
         *  Identifies a manifest file containing the I-frames of a multimedia presentation.  It stands alone, in that it does not apply to a particular URI in the manifest.
         *  Syntax:  #EXT-X-I-FRAME-STREAM-INF:<attribute-list>
         */
        public static const I_FRAME_STREAM_INF:String = "#EXT-X-I-FRAME-STREAM-INF:";
        
        /**
         *  Indicates the compatibility version of the Playlist file.
         *  Syntax:  #EXT-X-VERSION:<n>
         */
        public static const VERSION:String = "#EXT-X-VERSION:";

    }
}