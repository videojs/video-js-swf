package com.videojs.providers.hls.utils{

    import com.videojs.VideoJSModel;
    import com.videojs.providers.hls.HLSVideoProvider;
    import com.videojs.providers.hls.events.HLSErrorEvent;
    import com.videojs.providers.hls.events.HLSEvent;
import com.videojs.providers.hls.structs.HLSErrorEventMessage;
import com.videojs.providers.hls.structs.M3U8TagType;
    import com.videojs.providers.hls.structs.M3U8ZenTagType;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.utils.Console;

    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.TimerEvent;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;
    import flash.utils.Timer;

    public class ManifestManager extends EventDispatcher{

        private var _manifestURI:String = "";
        private var _manifestReloadInterval:Number = 5000;
        private var _useCacheBusting:Boolean = false; // Not yes used.
        private var _maxSegmentDuration:Number = -1;
        private var _totalDuration:Number = 0;
        private var _manifestLoader:URLLoader;
        private var _manifestIsLoading:Boolean = false;
        private var _manifestLoadCount:int = 0;
        private var _firstKnownSequenceID:int = -1;
        private var _lastKnownSequenceID:int = -1;
        private var _lastExtractedSequenceID:int = -1;
        private var _endlistEncountered:Boolean = false;
        private var _segments:Array;
        private var _currentSegmentStartIndex:int = 0;
        private var _currentSegment:StreamSegment;
        private var _firstSegmentLoaded:Boolean = false;
        private var _model:VideoJSModel;

        private var _moreDataPresent:Boolean;
        private var _isSeeking:Boolean = false;
        private var _frameTimeOffsetMS:int = 0;

		// MBR Support
		private var _renditions:Vector.<HLSRendition> = new Vector.<HLSRendition>();
		private var _currentRendition:HLSRendition;
		private var _autoSwitch:Boolean = true;
		private var _switching:Boolean = false;
		private var _currentIndex:int = 0;
		private var _initialIndex:int = 0;
		private var _currentBitrate:int = 0;
		private var _maxAllowedIndex:int = 0;
		private var _numDynamicStreams:int = 1;

		private var _useBandwidthDetection:Boolean = false;
		private var _currentBandwidth:int = 0; // This should be in kbps

        private var _secondsOfRetention:Number = 30; // The amount of video that we should download ahead of the current play point

		private var _auditTimer:Timer;
        private var _manifestReloadTimer:Timer; // Used to check for manifest updates in a "live" scenario

        private var _segmentParser:SegmentParser;
        private var _hlsProviderReference:HLSVideoProvider;

        public function ManifestManager(pHLSProviderReference:HLSVideoProvider){
            _model = VideoJSModel.getInstance();
            _hlsProviderReference = pHLSProviderReference;
            _segmentParser = new SegmentParser();
            _segments = [];
            _auditTimer = new Timer(500, 0);
            _auditTimer.addEventListener(TimerEvent.TIMER, onAuditTimerTick);
            _manifestReloadTimer = new Timer(_manifestReloadInterval, 0);
            _manifestReloadTimer.addEventListener(TimerEvent.TIMER, onManifestReloadTimerTick);
        }

		/* --- ADD MBR Support Start --- */

		public function set useBandwidthDetection(value:Boolean):void
		{
			_model.broadcastEventExternally("ManifestManager.useBWDetection:" + value);
			_useBandwidthDetection = value;
		}

		public function get useBandwidthDetection():Boolean
		{
			return _useBandwidthDetection;
		}

		public function get isDynamicStream():Boolean {
			return _numDynamicStreams > 1;
		}

		public function get initialIndex():int {
			return _initialIndex;
		}

		public function get currentIndex():int {
			return _currentIndex;
		}

		public function get currentRendition():HLSRendition {
			return _currentRendition;
		}

		public function get autoSwitch():Boolean {
			return _autoSwitch;
		}

		public function get switching():Boolean {
			return _switching;
		}

		public function get maxAllowedIndex():int {
			return _maxAllowedIndex;
		}

		public function get numDynamicStreams():int {
			return _numDynamicStreams;
		}

		public function get currentBitrate():int {
			return _currentBitrate;
		}

		public function switchTo(pIndex:int):void {
			_model.broadcastEventExternally("USER SWITCH REQUEST: " + pIndex);
			_currentIndex = pIndex;

			for each( var o:Object in renditions)
			{
				Console.log(renditions.indexOf(o), o.url);
				if( renditions.indexOf(o) == pIndex )
				{
					_manifestURI = o.url;
					_currentBitrate = o.bw;
					_model.broadcastEventExternally(HLSEvent.RENDITION_SELECTED, pIndex);
                }
			}

			setSwitching(true);
			init();

		}

		private function setSwitching( value:Boolean ):void
		{
			_switching = value;

			if( value )
			{
				_model.broadcastEventExternally(HLSEvent.SWITCH_START, {bandwidth: _currentBitrate, url: _manifestURI});

			} else
			{
				_model.broadcastEventExternally(HLSEvent.SWITCH_END, {bandwidth: _currentBitrate, url: _manifestURI});
            }
		}


		/* --- ADD MBR Support End --- */

        public function get segmentParser():SegmentParser{
            return _segmentParser;
        }

        public function set manifestURI(pURI:String):void{
            _manifestURI = pURI;
        }

        public function get bufferedBytes():uint{
            return 0;
        }

        public function get bufferedSeconds():uint{

            var __seconds:Number = 0;
            var __lastLoadedSegmentIndex:int = -1;

            for(var i:int = _currentSegmentStartIndex; i < _segments.length; i++){

				// we count the StreamSegment's length towards our buffered seconds whether it's done loading or not
                if((_segments[i] as StreamSegment).loadStarted || (_segments[i] as StreamSegment).loadCompleted){

                    if(__lastLoadedSegmentIndex == -1){
                        __lastLoadedSegmentIndex = i;
                        __seconds += (_segments[i] as StreamSegment).maxDuration;
                    }
                    else if(i == __lastLoadedSegmentIndex + 1){
                        __seconds += (_segments[i] as StreamSegment).maxDuration;
                        __lastLoadedSegmentIndex++;
                    }
                    else{
                        break;
                    }
                }
                else{
                    break;
                }
            }
            return __seconds;
        }

        public function get totalDuration():Number{
            return _totalDuration;
        }

        public function get isSeeking():Boolean{
            return _isSeeking;
        }

        public function get recalculatedPlayheadOffset():Number {
            if(_frameTimeOffsetMS != -1){
                return _frameTimeOffsetMS / 1000;
            }
            else{
                return 0;
            }
        }

        public function init():void{
            _maxSegmentDuration = -1;
            _totalDuration = 0;
            _endlistEncountered = false;
			_lastKnownSequenceID = -1;
            _manifestLoadCount = 0;
            _firstSegmentLoaded = false;
            stopAuditing();
            stopManifestReloading();
            if(_manifestURI != ""){
                loadManifest();
            }
            else{
                _model.broadcastEventExternally("#HLS#:ManifestManager-No manifest URI!");
            }
        }

        public function start():void{

			Console.log("ManifestManager.start()");

            startAuditing();
            startManifestReloading();
            doAudit();
        }

        public function stop():void{

			Console.log("ManifestManager.stop()");

            stopAuditing();
            stopManifestReloading();

            // stop all loading segments
            for(var i:int = 0; i < _segments.length; i++){
                if((_segments[i] as StreamSegment).loadStarted && !(_segments[i] as StreamSegment).loadCompleted){
                    (_segments[i] as StreamSegment).halt();
                }
            }

            // reset stuff
            _lastExtractedSequenceID = -1;
        }

        // Returns an entire segment's worth of data for injection into NetStream's play buffer
        public function getNextData():ByteArray{

			Console.log("ManifestManager.getNextData()");

            var __nextSegmentFound:Boolean = false;

            for(var i:int = _currentSegmentStartIndex; i < _segments.length; i++){
                if((_segments[i] as StreamSegment).sequenceID == _lastExtractedSequenceID + 1){
                    _currentSegment = (_segments[i] as StreamSegment);
                    __nextSegmentFound = true;
                    break;
                }
            }

            if(!__nextSegmentFound){
                return null;
            }
            else{

                var __data:ByteArray = new ByteArray();

                try {
					Console.log("ManifestManager.getNextData(): SegmentParser.parseSegmentBinaryData() for id: " + _currentSegment.sequenceID);
					Console.log("ManifestManager.getNextData(): SegmentParser.parseSegmentBinaryData() for StreamSegment.data length: " + (_currentSegment.data as ByteArray).length);
                    _segmentParser.parseSegmentBinaryData((_currentSegment.data as ByteArray));
                    while( _segmentParser.tagsAvailable() )
                    {
                        var tag:ByteArray = _segmentParser.getNextTag();
                        if(_frameTimeOffsetMS == -1){
                            _frameTimeOffsetMS = FlvTag.frameTime(tag);
                        }
                        __data.writeBytes(tag);
                    }
                    _lastExtractedSequenceID++;
                    // TODO flus at the end of the stream!
                }
                catch (error:Error)
                {
                    Console.log(error.message);
					Console.log("ManifestManager.getNextData() - SegmentParser Error!");
                }

                return __data;
            }
        }

        public function getEndData():ByteArray{
            var __data:ByteArray = new ByteArray();
            _segmentParser.flushTags();
            while(_segmentParser.tagsAvailable()){
                __data.writeBytes(_segmentParser.getNextTag());
            }
            return __data;
        }

        public function getSegmentIndexForPositionInSeconds(pPosition:Number):int{
			Console.log("ManifestManager.getSegmentIndexForPositionInSeconds(): Total Segments: " + _segments.length);
            for(var i:int = 0; i < _segments.length; i++){
                if((_segments[i] as StreamSegment).start <= pPosition && pPosition < (_segments[i] as StreamSegment).start + (_segments[i] as StreamSegment).maxDuration){
					Console.log("ManifestManager.getSegmentIndexForPositionInSeconds(): Segment " + i + " contains position: " + pPosition);
                    return i;
                }
            }
            return -1;
        }

        public function prepareSeekByStartSegmentIndex(pIndex:int):void{

			Console.log("ManifestManager.prepareSeekByStartSegmentIndex(" + pIndex + ")");

            _isSeeking = true;

			if(pIndex> 0){
				_segmentParser.doSeek();
			}
			else{
				reinitializeSegmentParser();
			}

            // declare the index of the segment that playback should begin within
            _currentSegmentStartIndex = pIndex;

            _frameTimeOffsetMS = -1;

            _firstKnownSequenceID = (_segments[pIndex] as StreamSegment).sequenceID;
            if(pIndex > 0){
                _lastExtractedSequenceID = (_segments[pIndex - 1] as StreamSegment).sequenceID;
            }
            else{
                _lastExtractedSequenceID = -1;
            }

			// loop through our segments and kill loading on any segment prior to the one we're starting at
			for(var i:int = 0; i < pIndex; i++){
				(_segments[i] as StreamSegment).halt();
				(_segments[i] as StreamSegment).invalidate();
			}

            start();
        }

		// For some reason, SegmentParser chokes on seeks to the 0 time point
		private function reinitializeSegmentParser():void{

		}

        // This timer will reload the manifest every 5 seconds.
        private function startManifestReloading():void{
            if(!_endlistEncountered){
                _manifestReloadTimer.start();
            }
        }

        private function stopManifestReloading():void{
            _manifestReloadTimer.stop();
            _manifestReloadTimer.reset();
        }

        private function loadManifest():void{
            if(_manifestLoader != null){
                _manifestLoader.removeEventListener(Event.COMPLETE, onManifestLoadComplete);
                _manifestLoader.removeEventListener(IOErrorEvent.IO_ERROR, onManifestLoadIOError);
                _manifestLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onManifestLoadSecurityError);
                _manifestLoader = null;
            }
            _manifestIsLoading = true;
            _manifestLoader = new URLLoader();
            _manifestLoader.addEventListener(Event.COMPLETE, onManifestLoadComplete);
            _manifestLoader.addEventListener(IOErrorEvent.IO_ERROR, onManifestLoadIOError);
            _manifestLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onManifestLoadSecurityError);
            _manifestLoader.load(new URLRequest(_manifestURI));
        }

        private function parseManifest(pManifestData:String, pIsFirstManifest:Boolean):void{

            if(pManifestData.indexOf(M3U8TagType.EXTM3U) != 0){
                _model.broadcastErrorEventExternally(HLSErrorEvent.INVALID_MANIFEST, {message: HLSErrorEventMessage.MANIFEST_INVALID});
            }

            var __lines:Array = pManifestData.split("\n");
            var __len:uint = __lines.length;
            var __currentLine:uint = 1;
            var __sequenceID:int = 0;
            var __segmentsAdded:int = 0;
			var __calculatedDuration:int = -1;

            if(pIsFirstManifest){
                _firstKnownSequenceID = __sequenceID;
            }

			if(_switching)
			{
				_segments = [];
			}

            while(__currentLine < __len){
				if(__lines[__currentLine].indexOf(M3U8TagType.PLAYLIST_TYPE) == 0){
					var _playlistType:String = String(__lines[__currentLine]).substr(M3U8TagType.PLAYLIST_TYPE.length);

					switch( _playlistType.toUpperCase() )
					{
						// Valid Tag Values
						case "VOD":
						case "EVENT":
						break;

						// Invalid Values
						default:
						_model.broadcastErrorEventExternally(HLSErrorEvent.INVALID_PLAYLIST, {message: HLSErrorEventMessage.PLAYLIST_INVALID});
						break;
					}
				}
                else if(__lines[__currentLine].indexOf(M3U8TagType.MEDIA_SEQUENCE) == 0){
                    var _tagValue:String = String(__lines[__currentLine]).substr(M3U8TagType.MEDIA_SEQUENCE.length)

					if(_tagValue == null || _tagValue.length == 0)
					{
						_model.broadcastErrorEventExternally(HLSErrorEvent.MEDIA_SEQUENCE_EMPTY, {message: HLSErrorEventMessage.MEDIA_SEQUENCE_EMPTY})
					} else if( isNaN(parseInt(_tagValue)) )
					{
						_model.broadcastErrorEventExternally(HLSErrorEvent.MEDIA_SEQUENCE_NAN, {message: HLSErrorEventMessage.MEDIA_SEQUENCE_NAN})
					} else {
						// is valid
					}

					__sequenceID = int(String(__lines[__currentLine]).substr(M3U8TagType.MEDIA_SEQUENCE.length));

					if(pIsFirstManifest){
                        _firstKnownSequenceID = __sequenceID;
                    }
                }
                else if(__lines[__currentLine].indexOf(M3U8TagType.TARGETDURATION) == 0){
					var _targetDurationValue:String = String(__lines[__currentLine]).substr(M3U8TagType.TARGETDURATION.length);

					if( !_targetDurationValue || _targetDurationValue.length == 0 )
					{
						// FIRE EMPTY
						_model.broadcastErrorEventExternally(HLSErrorEvent.TARGET_DURATION_EMPTY, {message: HLSErrorEventMessage.TARGET_DURATION_EMPTY } );
					} else if ( isNaN(Number(_targetDurationValue)) )
					{
						// FIRE NAN
						_model.broadcastErrorEventExternally(HLSErrorEvent.TARGET_DURATION_NAN, {message: HLSErrorEventMessage.TARGET_DURATION_NAN + ' : ' + _targetDurationValue } );
					} else if( Number(_targetDurationValue) <= 0 )
					{
						// FIRE INVALID
						_model.broadcastErrorEventExternally(HLSErrorEvent.TARGET_DURATION_INVALID, {message: HLSErrorEventMessage.TARGET_DURATION_INVALID } );
					} else {
						// Valid Value, set to Max Duration
						if(_maxSegmentDuration == -1)
						{
							_maxSegmentDuration = Number(_targetDurationValue);
						}
					}

				}
				else if (__lines[__currentLine].indexOf(M3U8ZenTagType.TOTALDURATION) == 0) {
					var _zenTotalDurationValue:String = String(__lines[__currentLine]).substr(M3U8ZenTagType.TOTALDURATION.length);

					if( !_zenTotalDurationValue || _zenTotalDurationValue.length == 0 )
					{
						// FIRE EMPTY
						_model.broadcastErrorEventExternally(HLSErrorEvent.ZEN_TOTAL_DURATION_EMPTY, {message: HLSErrorEventMessage.ZEN_TOTAL_DURATION_EMPTY } );
					} else if (isNaN(parseInt(_zenTotalDurationValue))) {
						// FIRE NAN
						_model.broadcastErrorEventExternally(HLSErrorEvent.ZEN_TOTAL_DURATION_NAN, {message: HLSErrorEventMessage.ZEN_TOTAL_DURATION_NAN } );
					} else if( _zenTotalDurationValue is Number && (_zenTotalDurationValue as Number) >= 0 )
					{
						_totalDuration = _zenTotalDurationValue as Number;
						_model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _totalDuration);
					}

				}
                else if(__lines[__currentLine].indexOf(M3U8TagType.EXTINF) == 0){
					// If Endlist is not recorded yet
					if(!_endlistEncountered) {
						// if this segment hasn't already been encountered
						if(__sequenceID > _lastKnownSequenceID || !_switching){
							var __lineValue:String = String(__lines[__currentLine]).substr(M3U8TagType.EXTINF.length);
							var __segmentStartIndex:Number = -1;
							var __segmentDuration:Number = -1;
							for( var i:int = 0; i < __lineValue.length; i++)
							{
								//Console.warn(i, __lineValue.charAt(i), __lineValue.charAt(i) == ','); //isNaN(parseInt(__lineValue.charAt(i))));
							    if(__lineValue.charAt(i) == ',') {
									var segDur:String = __lineValue.slice(0,i);

									if(segDur.length > 0) {
										if( isNaN( Number(segDur) ) )
										{
											//NAN
											_model.broadcastErrorEventExternally(HLSErrorEvent.SEGMENT_INF_NAN, {message: HLSErrorEventMessage.SEGMENT_INF_NAN });
										} else {
											// Valid
											__segmentDuration = Number(segDur);
										}
									} else {
										// Empty
										_model.broadcastErrorEventExternally(HLSErrorEvent.SEGMENT_INF_EMPTY, {message: HLSErrorEventMessage.SEGMENT_INF_EMPTY });
									}
								}
							}

							// No valid segment duration found on tag, use target duration if there is one.
							if( __segmentDuration == -1 && _maxSegmentDuration > 0)
							{
								//Console.warn('seetting seg duration to max duration');
								__segmentDuration = _maxSegmentDuration;
							}

							if ( __segmentDuration > _maxSegmentDuration )
							{
								// Fire Out of Range, Above TARGET_DURATION
								_model.broadcastErrorEventExternally(HLSErrorEvent.SEGMENT_INF_GREATER_THAN_TARGET, {message: HLSErrorEventMessage.SEGMENT_INF_GREATER_THAN_TARGET } );
								//Console.warn('Segment Duration GREATER than target', __segmentDuration, _maxSegmentDuration);
							}

							if(__segmentDuration)
							{
								if(__calculatedDuration == -1)
								{
									__calculatedDuration = 0;
									__segmentStartIndex = 0;
								} else {
									__segmentStartIndex = __calculatedDuration;
								}

								//Console.warn("Segment with duration of", __segmentDuration, 'added at index', __segmentStartIndex);

								__calculatedDuration += __segmentDuration;
							}

							var __segmentURI:String = getAbsoluteSegmentURI(__lines[__currentLine+1]);

							// Original
							//var __segment:StreamSegment = new StreamSegment(__segmentURI, __sequenceID, _maxSegmentDuration, (_segments.length * _maxSegmentDuration));
							// Fixed for variance
							var __segment:StreamSegment = new StreamSegment(__segmentURI, __sequenceID, __segmentDuration, __segmentStartIndex);
								__segment.addEventListener(HLSEvent.SEGMENT_LOADED, onSegmentLoaded);

							_segments.push(__segment);
							__segmentsAdded++;
							_lastKnownSequenceID++;
						}
					}
                    __sequenceID++;
                    __currentLine++;
                }
                else if(__lines[__currentLine].indexOf(M3U8TagType.ENDLIST) == 0){
					var _isLastLine:Boolean = false;

					// The first calculation may look one off, but the last increase of currentLine throws it off by one
					// The second calculation is to account for whitespace as the last line
					if( ((__currentLine + 1) == (__lines.length -1)) || __lines[__currentLine+1].toString().length == 0)
					{
						_isLastLine = true;
					}

					if(_endlistEncountered) {
						// Fire Warning DOUBLE
						_model.broadcastErrorEventExternally(HLSErrorEvent.ENDLIST_ALREADY_ENCOUNTERED, {message: HLSErrorEventMessage.ENDLIST_ALREADY_ENCOUNTERED } );
					}

					if(!_isLastLine) {
						// Fire Warning MIDDLE
						_model.broadcastErrorEventExternally(HLSErrorEvent.ENDLIST_NOT_LAST_LINE, {message: HLSErrorEventMessage.ENDLIST_NOT_LAST_LINE } );

					}

                    _endlistEncountered = true;

					Console.warn('done, what is duration?', _totalDuration, __calculatedDuration);

					if( ( __calculatedDuration > 0 && _totalDuration <= 0) && !_switching )
					{
						_totalDuration = __calculatedDuration;
						_model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE, _totalDuration);
					}
				}
                __currentLine++;
            }



			if( !_endlistEncountered )
			{
				Console.log('no end list encountered');
			}

        }

        private function parsePlaylist(pPlaylistData:String, pParentURI:String):Array{
            var __levels:Array = [];

            var __lines:Array = pPlaylistData.split("\n");
            var __len:uint = __lines.length;
            var __currentLine:uint = 1;
            var __directory:String = pParentURI.slice(0, pParentURI.lastIndexOf("/")+1);

			// first, we need to make sure this is a valid playlist
			// It must have at least one STREAM_INF
			if(pPlaylistData.indexOf(M3U8TagType.STREAM_INF) == -1)
			{
				_model.broadcastErrorEventExternally(HLSErrorEvent.INVALID_PLAYLIST, {message: HLSErrorEventMessage.PLAYLIST_EMPTY});
				return [];
			}

            while(__currentLine < __len){
                if(__lines[__currentLine].indexOf(M3U8TagType.STREAM_INF) == 0){

                    var __level:Object = {};
                    __level.bw = 0;
                    __level.url = "";

                    if(__lines[__currentLine].indexOf("BANDWIDTH=") != -1){
                        // HLS BUG //
                        // Broken on renditions with data listed AFTER BW in manifest
                        // i.e. -  #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=240000,RESOLUTION=396x224 //
                        // reports as 0 instead of 240000 //
                        // __level.bw = int(__lines[__currentLine].toString().slice(__lines[__currentLine].indexOf("BANDWIDTH=")+10));

                        // Fix //
                        // iterate through rest of line for next non numeric character or EOL
                        var lineContent:String = __lines[__currentLine] as String;
                        var startIndex:int = __lines[__currentLine].indexOf("BANDWIDTH=") + 10;
                        var endIndex:int = __lines[__currentLine].length-1;
                        var breakIndex:int;

                        for( var i:int = startIndex; i < endIndex; i++ )
                        {
                            if(i == endIndex-1)
                            {
                               __level.bw = int(lineContent.slice(startIndex));
                               break;
                            } else if (isNaN(parseInt(lineContent.charAt(i)))){
                               breakIndex = i;
                               __level.bw = int(lineContent.substr(startIndex,breakIndex-startIndex));
                               break;
                            };
                        };

                        _model.broadcastEventExternally("Rendition Loaded: "+ __levels.length.toString());

                    } else {
						// NO BANDWIDTH VALUE
					}

                    var __url:String = __lines[__currentLine+1];
                    if(__url.indexOf("http://") == -1 && __url.indexOf("https://") == -1){
                        __level.url = __directory + __url;
                    }
                    else{
                        __level.url = __url;
                    }
                    __levels.push(__level);
                    __currentLine++;
                }
                __currentLine++;
            }

			_model.broadcastEventExternally("MBR Manifest Parsed : Rendition Count: "+ __levels.length.toString());

			renditions = __levels;

            return __levels;
        }

		public var renditions:Array;

        private function getAbsoluteSegmentURI(pURI:String):String{

            var __prefix:String;

            if(pURI.indexOf("https://") != -1 || pURI.indexOf("http://") != -1){
                return pURI;
            }
            else if(pURI.charAt(0) == "/"){
                __prefix = _manifestURI.split("/")[0] + "//" + _manifestURI.split("/")[2];
                return __prefix + pURI;
            }
            else{
                __prefix = _manifestURI.substr(0, _manifestURI.lastIndexOf("/") + 1);
                return __prefix + pURI;
            }
        }

        private function startAuditing():void{
            _auditTimer.start();
        }

        private function stopAuditing():void{
            _auditTimer.stop();
            _auditTimer.reset();
        }

        private function doAudit():void{

            var __bufferedSecondsOffset:Number;

            if(_isSeeking){
                __bufferedSecondsOffset = _hlsProviderReference.targetSeekTime;
            }
            else{
                __bufferedSecondsOffset = _frameTimeOffsetMS / 1000;
            }
			//#1 Console.log("ManifestManager.doAudit(): __bufferedSecondsOffset: " + __bufferedSecondsOffset);

            var __segment:StreamSegment;
			var __actualSecondsPlayed:Number;
			var __actualSecondsBuffered:Number;

            // if we've seeked in to the stream at all
            if(__bufferedSecondsOffset > 0){

				if(_isSeeking){
					__actualSecondsPlayed = 0;
				}
				else{
					__actualSecondsPlayed = (_hlsProviderReference.time - __bufferedSecondsOffset);
				}

				__actualSecondsBuffered = bufferedSeconds - __actualSecondsPlayed;

                if(__actualSecondsBuffered < _secondsOfRetention){
                    __segment = getNextUnrequestedSegment();
                    if (__segment) {
                        if(__segment.load()){
                            //Console.log("ManifestManager.doAudit(): Calling StreamSegment.load() on next segment...");
                        }
                        else{
							//Console.log("ManifestManager.doAudit(): All segments loaded!");
                            dispatchEvent(new HLSEvent(HLSEvent.LAST_SEGMENT_LOADED, {}));
                            stopAuditing();
                        }
                    }
                }
                else{
                    if(_isSeeking){
                        _isSeeking = false;
                        dispatchEvent(new HLSEvent(HLSEvent.FIRST_SEEK_SEGMENT_LOADED, {}));
                    }
                }
            }
            // if we're playing from the beginning of the stream
            else{
				//#2 Console.log("ManifestManager.doAudit(): Playing from 'beginning' of stream!");
				//#3 Console.log("ManifestManager.doAudit(): bufferedSeconds: " + bufferedSeconds);


				if(_isSeeking){
					__actualSecondsPlayed = 0;
				}
				else{
					__actualSecondsPlayed = _hlsProviderReference.time;
				}
				//#4 Console.log("ManifestManager.doAudit(): __actualSecondsPlayed: " + __actualSecondsPlayed);

				__actualSecondsBuffered = bufferedSeconds - __actualSecondsPlayed;

                if(__actualSecondsBuffered < _secondsOfRetention){
                    __segment = getNextUnrequestedSegment();
                    if (__segment) {
                        if(__segment.load()){
							Console.log("ManifestManager.doAudit(): Calling StreamSegment.load() on next segment...");
                        }
                        else{
							Console.log("ManifestManager.doAudit(): All segments loaded!");
                            dispatchEvent(new HLSEvent(HLSEvent.LAST_SEGMENT_LOADED, {}));
                            stopAuditing();
                        }
                    }
                }
                else{
                    if(_isSeeking){
                        _isSeeking = false;
                        dispatchEvent(new HLSEvent(HLSEvent.FIRST_SEEK_SEGMENT_LOADED, {}));
                    }
                }
            }
        }

        private function getNextUnrequestedSegment():StreamSegment{
            var __segment:StreamSegment;
            for(var i:int = _currentSegmentStartIndex; i < _segments.length; i++){
              if(!(_segments[i] as StreamSegment).loadRequested){
                  __segment = (_segments[i] as StreamSegment);
                  break;
              }
            }
            return __segment;
        }

        private function expireSegmentBySegmentSequenceID(pID:int):void{
            for(var i:int = 0; i < _segments.length; i++){
                if((_segments[i] as StreamSegment).sequenceID == pID){
                    (_segments[i] as StreamSegment).expire();
                    (_segments[i] as StreamSegment).removeEventListener(HLSEvent.SEGMENT_LOADED, onSegmentLoaded);
                    _segments.splice(i,1);
                    break;
                }
            }
        }

        private function onManifestLoadComplete(e:Event):void{

            // If this .m3u8 is a playlist...
            if(_manifestLoader.data.indexOf(M3U8TagType.STREAM_INF) != -1){
                // Grab the enclosed manifest URLs
                var __levels:Array = parsePlaylist(_manifestLoader.data, _manifestURI);
                // If some exist...
                if(__levels.length> 0){

					_numDynamicStreams = __levels.length;
					_maxAllowedIndex = __levels.length - 1;
					_model.broadcastEventExternally("HLS MBR: isDynamicStreamChange");
					_model.broadcastEventExternally("HLS MBR: currentIndex:" + _currentIndex);
					_model.broadcastEventExternally("HLS MBR: maxIndex:" + _maxAllowedIndex);
					_model.broadcastEventExternally("HLS MBR: numDynamicStreams:" + _numDynamicStreams);
					_model.broadcastEventExternally(HLSEvent.DYNAMIC_STREAM_CHANGE, { renditions: __levels, currentIndex: _currentIndex, maxAllowedIndex: _maxAllowedIndex, numDynamicStreams: _numDynamicStreams} );

					_manifestURI = __levels[_initialIndex].url;
					_currentBitrate = __levels[_initialIndex].bw;
					loadManifest();
                    return;
                }
                // If none exist...
                else{
                    return;
                }
            }



            var __isFirst:Boolean = false;
            if(_manifestLoadCount == 0){
                __isFirst = true;
                dispatchEvent(new HLSEvent(HLSEvent.FIRST_MANIFEST_LOADED, {}));
            }
            dispatchEvent(new HLSEvent(HLSEvent.MANIFEST_LOADED, {}));
            _manifestLoadCount++;
            parseManifest(_manifestLoader.data, __isFirst);
            _manifestIsLoading = false;

			if(_switching)
			{
				setSwitching(false);
				_hlsProviderReference.seekBySeconds(_hlsProviderReference.time);
				Console.log(_hlsProviderReference.time, _hlsProviderReference.targetSeekTime);
			}

        }

        private function onManifestLoadIOError(e:IOErrorEvent):void{
            _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);
            _manifestIsLoading = false;
        }

        private function onManifestLoadSecurityError(e:SecurityErrorEvent):void{
            _model.broadcastErrorEventExternally(HLSErrorEvent.MANIFEST_LOAD_SECURITY_ERROR);
            _manifestIsLoading = false;
        }

        private function onAuditTimerTick(e:TimerEvent):void{
            doAudit();
        }

        private function onManifestReloadTimerTick(e:TimerEvent):void{

            if(_endlistEncountered){
                stopManifestReloading();
            }
            else{
                if(!_manifestIsLoading){
                    loadManifest();
                }
            }
        }

		private var _lastLoadedSegment:int;
        private var _runningBWvalues:Array = [];

        private function onSegmentLoaded(e:HLSEvent):void{
			_model.broadcastEventExternally("ManifestManager.onSegmentLoaded():"+(e.target as StreamSegment).sequenceID);

			if(_useBandwidthDetection)
			{
				if(!e.data.cached)
				{
					Console.log('Adding to BW Calculations', e.data.throughput);
					_runningBWvalues.push(e.data.throughput);

					Console.log('determine rolling avg.', _runningBWvalues.length);

					var _totalBW:Number = 0;

					for ( var i:int = 0; i < _runningBWvalues.length; i ++ ) {
						var _increase:Number = _runningBWvalues[i];
						Console.log('['+i+']' , _totalBW, '+', _increase, '=', (_totalBW + _increase) );
						_totalBW = (_totalBW + _increase);
                    }

					_model.broadcastEventExternally('bandwidth', {count: _runningBWvalues.length, total: _totalBW, average: Number(_totalBW/_runningBWvalues.length).toFixed(0), latest: e.data.throughput, unit: 'bps', collection: _runningBWvalues });

					if( _runningBWvalues.length >= 3 && _autoSwitch )
					{
						_model.broadcastEventExternally('rendition_switch_check');
						_runningBWvalues = _runningBWvalues.slice(_runningBWvalues.length-3, _runningBWvalues.length);
					}

					Console.log('=== avg', Number(_totalBW/_runningBWvalues.length).toFixed(0), 'over ' + _runningBWvalues.length + ' items');
				}
			}

			_lastLoadedSegment = (e.target as StreamSegment).sequenceID;

            if((e.target as StreamSegment).sequenceID == _firstKnownSequenceID){
                if(_isSeeking){
                    _isSeeking = false;
                    dispatchEvent(new HLSEvent(HLSEvent.FIRST_SEEK_SEGMENT_LOADED, {}));
                }
                else{
                    _model.broadcastEventExternally("- First sequence ID loaded!");
                    dispatchEvent(new HLSEvent(HLSEvent.FIRST_SEGMENT_LOADED, {}));
                }
            }
        }
    }
}

//_model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_READY, {ns:_ns}));
