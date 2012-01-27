package com.videojs.providers{
    import flash.media.Video;
    
    public interface IProvider{
        
        function get loop():Boolean;
        function set loop(pLoop:Boolean):void;
        
        function get time():Number;
        function get duration():Number;
        function get readyState():int;
        function get networkState():int;
        function get buffered():Number;
        function get bufferedBytesEnd():int;
        function get bytesLoaded():int;
        function get bytesTotal():int;
        function get playing():Boolean;
        function get paused():Boolean;
        function get ended():Boolean;
        function get seeking():Boolean;
        function get usesNetStream():Boolean;
        function get metadata():Object;
        function get srcAsString():String;
        function set src(pSrc:Object):void;
        
        function init(pSrc:Object):void;
        function load():void;
        function play():void;
        function pause():void;
        function resume():void;
        function seekBySeconds(pTime:Number):void;
        function seekByPercent(pPercent:Number):void;
        function stop():void;
        function attachVideo(pVideo:Video):void;
        function die():void;
        
    }
}