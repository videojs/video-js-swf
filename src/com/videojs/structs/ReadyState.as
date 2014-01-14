package com.videojs.structs{
    
    public class ReadyState {
        // No information regarding the media resource is available. No data for the current playback position is available
        public static const HAVE_NOTHING:Number = 0;
        // Enough of the resource has been obtained that the duration of the resource is available. In the case of a video element, the dimensions of the video are also available. The API will no longer throw an exception when seeking. No media data is available for the immediate current playback position.
        public static const HAVE_METADATA:Number = 1;
        // Data for the immediate current playback position is available, but either not enough data is available that the user agent could successfully advance the current playback position in the direction of playback at all without immediately reverting to the HAVE_METADATA state, or there is no more data to obtain in the direction of playback. For example, in video this corresponds to the user agent having data from the current frame, but not the next frame, when the current playback position is at the end of the current frame; and to when playback has ended.
        public static const HAVE_CURRENT_DATA:Number = 2;
        // Data for the immediate current playback position is available, as well as enough data for the user agent to advance the current playback position in the direction of playback at least a little without immediately reverting to the HAVE_METADATA state, and the text tracks are ready. For example, in video this corresponds to the user agent having data for at least the current frame and the next frame when the current playback position is at the instant in time between the two frames, or to the user agent having the video data for the current frame and audio data to keep playing at least a little when the current playback position is in the middle of a frame. The user agent cannot be in this state if playback has ended, as the current playback position can never advance in this case.
        public static const HAVE_FUTURE_DATA:Number = 3;
        //  All the conditions described for the HAVE_FUTURE_DATA state are met, and, in addition, either of the following conditions is also true:
        //    The user agent estimates that data is being fetched at a rate where the current playback position, if it were to advance at the effective playback rate, would not overtake the available data before playback reaches the end of the media resource.
        //    The user agent has entered a state where waiting longer will not result in further data being obtained, and therefore nothing would be gained by delaying playback any further. (For example, the buffer might be full.)
        public static const HAVE_ENOUGH_DATA:Number = 4;
    }
}