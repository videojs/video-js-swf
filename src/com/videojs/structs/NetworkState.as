package com.videojs.structs{
    
    public class NetworkState{
        // The element has not yet been initialized. All attributes are in their initial states.    
        public static const NETWORK_EMPTY:Number = 0;
        // The element has selected a resource, but it is not actually using the network at this time.
        public static const NETWORK_IDLE:Number = 1;
        // The user agent is actively trying to download data.
        public static const NETWORK_LOADING:Number = 2;
        // The element has not yet found a resource to use. 
        public static const NETWORK_NO_SOURCE:Number = 3;
    }
}