package com.videojs.providers{
    
    import flash.media.Video;
    import flash.utils.ByteArray;
    
    public class HLSProvider implements IProvider{

        private var _loop:Boolean = false;
        
        public function get loop():Boolean{
            return _loop;
        }
        
        public function set loop(pLoop:Boolean):void{
            _loop = pLoop;
        }
        
        /**
         * Should return a value that indicates the current playhead position, in seconds.
         */ 
        public function get time():Number {
          return 0;
        }
        
        /**
         * Should return a value that indicates the current asset's duration, in seconds.
         */
        public function get duration():Number  {
          return 0;
        }

        /**
         * Appends the segment data in a ByteArray to the source buffer.
         * @param  bytes the ByteArray of data to append.
         */
        public function appendBuffer(bytes:ByteArray):void {
          return;
        }
        
        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's readyState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */ 
        public function get readyState():int {
          return 0;
        }
        
        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's networkState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */ 
        public function get networkState():int {
          return 0;
        }
        
        /**
         * Should return the amount of media that has been buffered, in seconds, or 0 if
         * this value is unknown or unable to be determined (due to lack of duration data, etc)
         */
        public function get buffered():Number {
          return 0;
        }
        
        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bufferedBytesEnd():int {
          return 0;
        }
        
        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bytesLoaded():int {
          return 0;
        }
        
        /**
         * Should return the total bytes of the current asset, or 0 if this value is
         * unknown or unable to be determined (due to streaming, bitrate switching, etc)
         */
        public function get bytesTotal():int{
          return 0;
        }
        
        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is playing.
         */
        public function get playing():Boolean {
          return false;
        }
        
        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is paused.
         */
        public function get paused():Boolean {
          return true;
        }
        
        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset has ended. This value should default to false, and be reset with every seek request within
         * the same asset.
         */
        public function get ended():Boolean {
          return false;
        }
        
        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is in the process of seeking to a new time point.
         */
        public function get seeking():Boolean {
          return false;
        }
        
        /**
         * Should return a boolean value that indicates whether or not this provider uses the NetStream class.
         */
        public function get usesNetStream():Boolean {
          return true;
        }
        
        /**
         * Should return an object that contains metadata properties, or an empty object if metadata doesn't exist.
         */
        public function get metadata():Object {
          return null;
        }
        
        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function get srcAsString():String {
          return "string";
        }
        
        /**
         * Should contain an object that enables the provider to play whatever media it's designed to play.
         * Compare the difference in implementation between HTTPVideoProvider and RTMPVideoProvider to see
         * one example of how this object can be used.
         */
        public function set src(pSrc:Object):void {
          return;
        }
        
        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function init(pSrc:Object, pAutoplay:Boolean):void {
          return;
        }
        
        /**
         * Called when the media asset should be preloaded, but not played.
         */
        public function load():void {
          return;
        }
        
        /**
         * Called when the media asset should be played immediately.
         */
        public function play():void {
          return;
        }
        
        /**
         * Called when the media asset should be paused.
         */
        public function pause():void {
          return;
        }
        
        /**
         * Called when the media asset should be resumed from a paused state.
         */
        public function resume():void {
          return;
        }
        
        /**
         * Called when the media asset needs to seek to a new time point.
         */
        public function seekBySeconds(pTime:Number):void {
          return;
        }
        
        /**
         * Called when the media asset needs to seek to a percentage of its total duration.
         */     
        public function seekByPercent(pPercent:Number):void {
          return;
        }
        
        /**
         * Called when the media asset needs to stop.
         */
        public function stop():void {
          return;
        }
        
        /**
         * For providers that employ an instance of NetStream, this method is used to connect that NetStream
         * with an external Video instance without exposing it.
         */
        public function attachVideo(pVideo:Video):void {
          return;
        }
        
        /**
         * Called when the provider is about to be disposed of.
         */
        public function die():void {
          return;
        }
    }
}