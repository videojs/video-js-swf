package com.videojs.providers.hls.utils{

    import com.videojs.VideoJSModel;
import com.videojs.providers.hls.events.HLSErrorEvent;
import com.videojs.providers.hls.events.HLSEvent;
import com.videojs.providers.hls.structs.HLSErrorEventMessage;
import com.videojs.utils.Console;

import flash.events.ErrorEvent;
    import flash.events.Event;
    import flash.events.EventDispatcher;
import flash.events.HTTPStatusEvent;
import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;

    public class StreamSegment extends EventDispatcher{

		private static const CACHE_THRESHOLD:int = 75;

        private var _uri:String;
        private var _sequenceID:int;
        private var _maxDuration:Number;
        private var _start:Number = 0;
        private var _data:ByteArray;
        private var _loadRequested:Boolean = false;
        private var _loadStarted:Boolean = false;
        private var _loadCompleted:Boolean = false;
        private var _loadErrored:Boolean = false;
        private var _isErrorFatal:Boolean = false;
        private var _loadThroughput:uint = 0;
        private var _loadStartTimestamp:Number;
		private var _loadCompleteTimestamp:Number;
        private var _model:VideoJSModel;
        private var _segmentLoader:URLLoader;
		private var _isCached:Boolean = false;
        // a sorted list of FLV tags
        private var _tags:Array = [];

        public function StreamSegment(pURI:String, pSequenceID:int, pMaxDuration:Number, pStart:Number = 0){
            _model = VideoJSModel.getInstance();
            _uri = pURI;
            _sequenceID = pSequenceID;
            _maxDuration = pMaxDuration;
            _start = pStart;
            //_parser = new TSParser();
        }

        public function get uri():String{
            return _uri;
        }
        public function set uri(pURI:String):void{
            _uri = pURI;
        }

        public function get sequenceID():int{
            return _sequenceID;
        }

        public function get maxDuration():Number{
            return _maxDuration;
        }

        public function get start():Number{
            return _start;
        }
        public function set start(pStart:Number):void{
            _start = pStart;
        }

        public function get data():ByteArray{
            return _data;
        }

        public function get loadRequested():Boolean{
            return _loadRequested;
        }

        public function get loadStarted():Boolean{
            return _loadStarted;
        }

        public function get loadCompleted():Boolean{
            return _loadCompleted;
        }

        public function load():Boolean{
            if(!loadRequested){
                loadSegmentData();
                return true;
            }
            else{
                return false;
            }

        }

        public function halt():void {

			if(_segmentLoader == null){
				return;
			}

            _segmentLoader.removeEventListener(Event.COMPLETE, onSegmentLoadComplete);
            _segmentLoader.removeEventListener(IOErrorEvent.IO_ERROR, onSegmentLoadIOError);
            _segmentLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSegmentLoadSecurityError);
            // If there's no load in progress, an exception is thrown, so we wrap this.
            try {
                _segmentLoader.close();
            }
            catch(e:Error){

            }

            _loadRequested = false;
			_loadStarted = false;
        }

        public function invalidate():void{
            _data = null;
            _loadRequested = false;
            _loadStarted = false;
            _loadCompleted = false;
            _loadErrored = false;
            _isErrorFatal = false;
            _loadThroughput = 0;
            _loadStartTimestamp = 0;
        }

        public function expire():void{
            if(_segmentLoader != null){
                if(_loadStarted){
                    _segmentLoader.close();
                }
                _segmentLoader.removeEventListener(Event.COMPLETE, onSegmentLoadComplete);
				_segmentLoader.removeEventListener(IOErrorEvent.IO_ERROR, onSegmentLoadIOError);
                _segmentLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSegmentLoadSecurityError);
				_segmentLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onHTTPStatusEvent);
				_segmentLoader = null;
            }
        }

        private function loadSegmentData():void{

            if(_segmentLoader != null){
                if(_loadStarted){
                    try{
                      _segmentLoader.close();
                    }
                    catch(e:Error){}
                }
                _segmentLoader.removeEventListener(Event.COMPLETE, onSegmentLoadComplete);
                _segmentLoader.removeEventListener(IOErrorEvent.IO_ERROR, onSegmentLoadIOError);
                _segmentLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSegmentLoadSecurityError);
				_segmentLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onHTTPStatusEvent);
				_segmentLoader = null;
            }

            _loadRequested = true;
            _loadStarted = true;
            _loadCompleted = false;
            _loadErrored = false;
            _isErrorFatal = false;

            _segmentLoader = new URLLoader();
			_segmentLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHTTPStatusEvent);
			_segmentLoader.addEventListener(Event.OPEN, onSegmentOpen)
			_segmentLoader.addEventListener(Event.COMPLETE, onSegmentLoadComplete);
            _segmentLoader.addEventListener(IOErrorEvent.IO_ERROR, onSegmentLoadIOError);
            _segmentLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSegmentLoadSecurityError);
            _segmentLoader.dataFormat = URLLoaderDataFormat.BINARY;
            _segmentLoader.load(new URLRequest(_uri));

        }

		private function onSegmentOpen(e:Event):void{
			_loadStartTimestamp = new Date().time;
		}

		private function onHTTPStatusEvent(e:HTTPStatusEvent):void {
			switch(e.status)
			{
				case 404:
					_model.broadcastErrorEventExternally( HLSErrorEvent.SEGMENT_MISSING, { message:HLSErrorEventMessage.SEGMENT_MISSING })
					break;

				case 500:
					_model.broadcastErrorEventExternally( HLSErrorEvent.SEGMENT_DOWNLOAD_ERROR, { message:HLSErrorEventMessage.SEGMENT_DOWNLOAD_ERROR })
					break;

				default:
					break;
			}
		}

        private function onSegmentLoadComplete(e:Event):void{
            _data = _segmentLoader.data;
            _loadCompleted = true;
			_loadCompleteTimestamp = new Date().time;

			Console.log('==================');
			Console.log(_segmentLoader.bytesTotal, 'bytes loaded');
			Console.log( (_loadCompleteTimestamp - _loadStartTimestamp), 'ms.' );

			var _deltaMS:int = int(_loadCompleteTimestamp - _loadStartTimestamp);

			if( _deltaMS < CACHE_THRESHOLD ){
				_isCached = true;
			} else if ( _deltaMS < 1000 ) {
				_loadThroughput = Math.round((_segmentLoader.bytesLoaded*1000)/_deltaMS);
			} else {
				_loadThroughput = Math.round(_segmentLoader.bytesTotal/(_deltaMS/1000));
			}

			Console.log('isCached?', _isCached );
			Console.log(_loadThroughput, 'bytes per second (Bps)');
			Console.log(_loadThroughput*8, 'bits per second (bps)', '[HLS Benchmark]');
			Console.log('==================');

			dispatchEvent(new HLSEvent(HLSEvent.SEGMENT_LOADED, {cached: _isCached, throughput: _loadThroughput*8}));
        }

        private function onSegmentLoadIOError(e:IOErrorEvent):void{
            _loadErrored = true;
        }

        private function onSegmentLoadSecurityError(e:SecurityErrorEvent):void{
            _loadErrored = true;
            _isErrorFatal = true;
        }

    }
}
