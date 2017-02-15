package com.videojs.providers{

    import flash.media.Video;
    import flash.utils.ByteArray;

    public interface IProvider{

        /**
         * Should return a value that indicates whether or not looping is enabled.
         */
        function get loop():Boolean;

        /**
         * See above.
         */
        function set loop(pLoop:Boolean):void;

        /**
         * Should return a value that indicates the current playhead position, in seconds.
         */
        function get time():Number;

        /**
         * Should return a value that indicates the current asset's duration, in seconds.
         */
        function get duration():Number;

        /**
         * Appends the segment data in a ByteArray to the source buffer.
         * @param  bytes the ByteArray of data to append.
         */
        function appendBuffer(bytes:ByteArray):void;

        /**
         * Indicates that no further bytes will appended to the source
         * buffer. After this method has been called, reaching the end
         * of buffered input is equivalent to the end of the media.
         */
        function endOfStream():void;

        /**
         * Aborts any data currently in the buffer and resets the decoder.
         * @see https://dvcs.w3.org/hg/html-media/raw-file/tip/media-source/media-source.html#widl-SourceBuffer-abort-void
         */
        function abort():void;

        /**
         * Indicates the next bytes of content will have timestamp
         * values that are not contiguous with the current playback
         * timeline.
         */
        function discontinuity():void;

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's readyState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        function get readyState():int;

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's networkState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        function get networkState():int;

        /**
         * Should return an array of normalized time ranges currently
         * buffered of the media, in seconds.
         */
        function get buffered():Array;

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        function get bufferedBytesEnd():int;

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        function get bytesLoaded():int;

        /**
         * Should return the total bytes of the current asset, or 0 if this value is
         * unknown or unable to be determined (due to streaming, bitrate switching, etc)
         */
        function get bytesTotal():int;

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is playing.
         */
        function get playing():Boolean;

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is paused.
         */
        function get paused():Boolean;

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset has ended. This value should default to false, and be reset with every seek request within
         * the same asset.
         */
        function get ended():Boolean;

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is in the process of seeking to a new time point.
         */
        function get seeking():Boolean;

        /**
         * Should return a boolean value that indicates whether or not this provider uses the NetStream class.
         */
        function get usesNetStream():Boolean;

        /**
         * Should return an object that contains metadata properties, or an empty object if metadata doesn't exist.
         */
        function get metadata():Object;

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        function get srcAsString():String;

        /**
         * Should contain an object that enables the provider to play whatever media it's designed to play.
         * Compare the difference in implementation between HTTPVideoProvider and RTMPVideoProvider to see
         * one example of how this object can be used.
         */
        function set src(pSrc:Object):void;

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        function init(pSrc:Object, pAutoplay:Boolean):void;

        /**
         * Called when the media asset should be preloaded, but not played.
         */
        function load():void;

        /**
         * Called when the media asset should be played immediately.
         */
        function play():void;

        /**
         * Called when the media asset should be paused.
         */
        function pause():void;

        /**
         * Called when the media asset should be resumed from a paused state.
         */
        function resume():void;

        /**
         * Called when current time needs to be adjusted slightly without seeking
         */
        function adjustCurrentTime(pValue:Number):void;

        /**
         * Called when the media asset needs to seek to a new time point.
         */
        function seekBySeconds(pTime:Number):void;

        /**
         * Called when the media asset needs to seek to a percentage of its total duration.
         */
        function seekByPercent(pPercent:Number):void;

        /**
         * Called when the media asset needs to stop.
         */
        function stop():void;

        /**
         * For providers that employ an instance of NetStream, this method is used to connect that NetStream
         * with an external Video instance without exposing it.
         */
        function attachVideo(pVideo:Video):void;

        /**
         * Called when the provider is about to be disposed of.
         */
        function die():void;

    }
}
