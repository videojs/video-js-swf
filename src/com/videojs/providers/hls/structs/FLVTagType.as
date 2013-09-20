package com.videojs.providers.hls.structs{
    
    /**
     * http://en.wikipedia.org/wiki/Flv#FLV_File_Structure
     */    
    
    public class FLVTagType{
        
        public static const METADATA:String = "FLVTagType.METADATA";
        
        public static const AUDIO:String = "FLVTagType.AUDIO";
        public static const MP3:String = "FLVTagType.MP3";
        public static const AAC_HEADER:String = "FLVTagType.AAC_HEADER";
        public static const AAC:String = "FLVTagType.AAC";
        
        public static const VIDEO:String = "FLVTagType.VIDEO";
        public static const AVC_HEADER:String = "FLVTagType.AVC_HEADER";
        public static const AVC_NAL_UNIT:String = "FLVTagType.AVC_NAL_UNIT";
    }
}