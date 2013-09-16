package com.videojs.providers.hls.utils{

import com.videojs.utils.Console;

import flash.utils.ByteArray;
    import flash.utils.Endian;
    import com.videojs.providers.hls.utils.FlvTag;

    public class AacStream
    {
        public var tags:Array = new Array;

        private var next_pts:uint;
        private var pts_delta:int = -1;
        private var state:uint;
        private var pes_length:int;

        private var adtsProtectionAbsent:Boolean;
        private var adtsObjectType:int;
        private var adtsSampleingIndex:int;
        private var adtsChanelConfig:int;
        private var adtsFrameSize:int;
        private var adtsSampleCount:int;
        private var adtsDuration:int;

        private static const adtsSampleingRates:Array = new Array(96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000);
        private var aacFrame:FlvTag = null;

        private var extraData:uint;

        public function AacStream()
        {}

        public function setNextTimeStamp(pts:uint, pes_size:int, dataAligned:Boolean):void
        {
            if (0>pts_delta) // We assume the very firts pts is less than 0x80000000
                pts_delta = pts;

            next_pts = pts - pts_delta;
            pes_length = pes_size;

            // If data is aligned, flush all internal buffers
            if (dataAligned)
                state = 0;
        }

        public function writeBytes(pData:ByteArray, o:int = 0, l:int = 0):void
        {
             // Do not allow more that 'pes_length' bytes to be written
            l = ( pes_length < l ? pes_length : l ); pes_length -= l;
            var e:int = o + l;
            while(o < e)
            switch( state )
            {
                default: case 0: if( o >= e ) return;
                if( 0xFF != pData[o] )
                {
                    Console.log("Error no ATDS header found")
                    o += 1; state = 0; return;
                }

                o += 1; state = 1; case 1: if( o >= e ) return;
                if( 0xF0 != ( pData[o] & 0xF0 ) )
                {
                    Console.log("Error no ATDS header found")
                    o +=1; state = 0; return;
                }

                adtsProtectionAbsent = Boolean( pData[o] & 0x01 );

                o += 1; state = 2; case 2: if( o >= e ) return;
                adtsObjectType     = ( ( pData[o] & 0xC0 ) >>>  6 ) + 1;
                adtsSampleingIndex = ( ( pData[o] & 0x3C ) >>>  2 );
                adtsChanelConfig   = ( ( pData[o] & 0x01 )  <<  2 );

                o += 1; state = 3; case 3: if( o >= e ) return;
                adtsChanelConfig |= ( (  pData[o] & 0xC0 ) >>>  6 );
                adtsFrameSize     = ( (  pData[o] & 0x03 )  << 11 );

                o += 1; state = 4; case 4: if( o >= e ) return;
                adtsFrameSize |= ( ( pData[o] ) <<  3 );

                o += 1; state = 5; case 5: if( o >= e ) return;
                adtsFrameSize |= ( ( pData[o] & 0xE0 ) >>>  5 );
                adtsFrameSize -= ( adtsProtectionAbsent ? 7 : 9 );

                o += 1; state = 6; case 6: if( o >= e ) return;
                adtsSampleCount = ( ( pData[o] & 0x03 ) + 1 ) * 1024;
                adtsDuration    = ( adtsSampleCount * 1000) / adtsSampleingRates[adtsSampleingIndex];

                var newExtraData:uint = (adtsObjectType << 11) | (adtsSampleingIndex << 7) | (adtsChanelConfig << 3);
                if ( newExtraData != extraData )
                {
                    aacFrame = new FlvTag(FlvTag.METADATA_TAG);
                    aacFrame.pts = next_pts;
                    aacFrame.dts = next_pts;

                    aacFrame.writeMetaDataDouble ("audiocodecid"   , 10  ); // AAC is always 10
                    aacFrame.writeMetaDataBoolean("stereo"         , 2 == adtsChanelConfig );
                    aacFrame.writeMetaDataDouble ("audiosamplerate", adtsSampleingRates[adtsSampleingIndex]  );
                    aacFrame.writeMetaDataDouble ("audiosamplesize", 16  ); // Is AAC always 16 bit?

                    tags.push( aacFrame );

                    extraData    = newExtraData;
                    aacFrame     = new FlvTag(FlvTag.AUDIO_TAG, true);
                    aacFrame.pts = aacFrame.dts;
                    aacFrame.pts = next_pts; // For audio, DTS is always the same as PTS. We want to set the DTS however so we can compare with video DTS to determine approximate packet order
                    aacFrame.writeShort( newExtraData );

                    tags.push( aacFrame );
                }

                // Skip the checksum if there is one
                o += 1; state = 7; case 7:
                if ( ! adtsProtectionAbsent )
                    if( 2 > (e-o) )
                        return;
                    else
                        o += 2;

                aacFrame = new FlvTag(FlvTag.AUDIO_TAG);
                aacFrame.pts = next_pts;
                aacFrame.dts = next_pts;
                state = 8; case 8:
                while( adtsFrameSize )
                {
                    if( o >= e ) return;
                    var bytesToCopy:int = (e-o) < adtsFrameSize ? (e-o) : adtsFrameSize;
                    aacFrame.writeBytes( pData, o, bytesToCopy );
                    o += bytesToCopy;
                    adtsFrameSize -= bytesToCopy;
                }

                tags.push( aacFrame );

                // finished with this frame
                state = 0;
                next_pts += adtsDuration;
            }
        }
    }
}
