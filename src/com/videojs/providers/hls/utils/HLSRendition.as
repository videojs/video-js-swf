package com.videojs.providers.hls.utils {

public class HLSRendition {

	private var _url:String;
	private var _directory:String;
	private var _bandwidth:int;
	private var _mediaWidth:int;
	private var _mediaHeight:int;
	private var _current:Boolean;

	public function HLSRendition() {
		_url = "";
		_directory = "";
		_bandwidth = 0;
		_mediaWidth = 0;
		_mediaHeight = 0;
		_current = false;
	}

	public function get isCurrent():Boolean {
		return _current;
	}

	public function set isCurrent(pCurrent:Boolean):void {
		_current = pCurrent;
	}

	public function get bandwidth():int	{
		return _bandwidth;
	}

	public function set bandwidth(pBandwidth:int):void {
		_bandwidth = pBandwidth;
	}

	public function get url():String {
		return _url;
	}

	public function set url(pUrl:String):void {
		_url = pUrl;
	}

	public function get mediaWidth():int {
		return _mediaWidth;
	}

	public function set mediaWidth(pWidth:int):void {
		_mediaWidth = pWidth;
	}

	public function get mediaHeight():int {
	   return _mediaHeight;
	}

	public function set mediaHeight(pHeight:int):void {
		_mediaHeight = pHeight;
	}

	public function get directory():String {
		return _directory;
	}

	public function set directory(pDirectory:String):void {
		_directory = pDirectory;
	}
}
}
