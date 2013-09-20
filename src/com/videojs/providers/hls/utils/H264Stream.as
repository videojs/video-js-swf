package com.videojs.providers.hls.utils{

    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public class H264Stream
    {
        public var tags:Array = new Array;

        private var next_pts:uint;
        private var next_dts:uint;
        private var pts_delta:int = -1;

        private var h264Frame:FlvTag = null;

        private var oldExtraData:H264ExtraData = new H264ExtraData;
        private var newExtraData:H264ExtraData = new H264ExtraData;

        public function H264Stream()
        {}

        private var nalUnitType:int = -1;
        public function setNextTimeStamp(pts:uint, dts:uint, dataAligned:Boolean):void
        {
            if (0>pts_delta) // We assume the very first pts is less than 0x8FFFFFFF (max signed int32)
                pts_delta = pts;

            // We could end up with a DTS less than 0 here. We need to deal with that!
            next_pts = pts - pts_delta;
            next_dts = dts - pts_delta;

            // If data is aligned, flush all internal buffers
            if( dataAligned )
                finishFrame();
        }

        public function finishFrame():void
        {
            if( null != h264Frame )
            {
                // Push SPS before EVERY IDR frame fo seeking
                if( newExtraData.extraDataExists() )
                {
                    oldExtraData = newExtraData;
                    newExtraData = new H264ExtraData;
                }

                if ( true == h264Frame.keyFrame )
                { // Push extra data on every IDR frame in case we did a stream change + seek
                    tags.push( oldExtraData.metaDataTag (h264Frame.pts) );
                    tags.push( oldExtraData.extraDataTag(h264Frame.pts) );
                }

                h264Frame.endNalUnit();
                tags.push( h264Frame );
            }

            h264Frame = null
            nalUnitType = -1;
            state = 0;
        }

        private var state:uint;
        public function writeBytes(pData:ByteArray, o:int, l:int):void
        {
            if ( 0 >= l ) return;
            switch(state)
            {
                default: case 0: state = 1;
/*--------------------------------------------------------------------------------------------------------------------*/
                case 1: // We are looking for overlaping start codes
                if( 1 >= pData[o] )
                {
                    var nalUnitSize:uint = ( null == h264Frame ) ? 0 : h264Frame.nalUnitSize();
                    if ( 1 <= nalUnitSize && 0 == h264Frame.negIndex(1) )
                    { // ?? ?? 00 | O[01] ?? ??
                        if ( 1 == pData[o] && 2 <= nalUnitSize && 0 == h264Frame.negIndex(2) )
                        { // ?? 00 00 : 01
                            if ( 3 <= nalUnitSize && 0 == h264Frame.negIndex(3) )
                                h264Frame.length -= 3; // 00 00 00 : 01
                            else
                                h264Frame.length -= 2; // 00 00 : 01

                            state = 3;
                            return this.writeBytes(pData,o+1,l-1);
                        }

                        if ( 1 < l && 0 == pData[o] && 1 == pData[o+1] )
                        { // ?? 00 | 00 01
                            if ( 2 <= nalUnitSize && 0 == h264Frame.negIndex(2) )
                                h264Frame.length -= 2; // 00 00 : 00 01
                            else
                                h264Frame.length -= 1; // 00 : 00 01

                            state = 3;
                            return this.writeBytes(pData,o+2,l-2);
                        }

                        if ( 2 < l && 0 == pData[o] && 0 == pData[o+1]  && 1 == pData[o+2] )
                        { // 00 | 00 00 01
                            h264Frame.length -= 1;
                            state = 3;
                            return this.writeBytes(pData,o+3,l-3);
                        }
                    }
                } // allow fall through if the above fails, we may end up checking a few bytes a second time. But that case will be VERY rare
/*--------------------------------------------------------------------------------------------------------------------*/
                case 2: // Look for start codes in pData
                var s:uint = o; // s = Start
                var e:uint = s + l; // e = End
                for ( var t:int = e - 3 ; o < t ; )
                {
                    if ( 1 < pData[o+2] )
                        o += 3; // if pData[o+2] is greater than 1, there is no way a start code can begin before o+3
                    else
                    if ( 0 != pData[o+1] )
                        o += 2;
                    else
                    if ( 0 != pData[o] )
                        o += 1;
                    else
                    { // If we get here we have 00 00 00 or 00 00 01
                        if ( 1 == pData[o+2] )
                        {
                            if ( o > s) h264Frame.writeBytes( pData, s, o-s );
                            state = 3; o += 3;
                            return writeBytes( pData, o, e-o );
                        }

                        if ( 4 <= e-o && 0 == pData[o+2] && 1 == pData[o+3] )
                        {
                            if ( o > s) h264Frame.writeBytes( pData, s, o-s );
                            state = 3; o += 4;
                            return writeBytes( pData, o, e-o);
                        }

                        // We are at the end of the buffer, or we have 3 NULLS followed by something that is not a 1, eaither way we can step forward by at least 3
                        o += 3;
                    }
                }

                // We did not find any start codes. Try again next packet
                state = 1;
                h264Frame.writeBytes( pData, s, l );
                return;
/*--------------------------------------------------------------------------------------------------------------------*/
                case 3: // The next byte is the first byte of a NAL Unit
                if ( null != h264Frame )
                {
                    switch (nalUnitType)
                    { // We are still operating on the previous NAL Unit
                        case  7: h264Frame.endNalUnit( newExtraData.addSPS() ); break;
                        case  8: h264Frame.endNalUnit( newExtraData.addPPS() ); break;

                        case  5: h264Frame.keyFrame = true;// Allow this to move on to default
                        default: h264Frame.endNalUnit(); break;
                    }
                }

                nalUnitType = pData[o] & 0x1F;
                if ( null != h264Frame && 9 == nalUnitType )
                    finishFrame(); // We are starting a new access unit. Flush the previous one

                // finishFrame may render h264Frame null, so we must test again
                if ( null == h264Frame )
                {
                    h264Frame = new FlvTag(FlvTag.VIDEO_TAG);
                    h264Frame.pts = next_pts;
                    h264Frame.dts = next_dts;
                }

                h264Frame.startNalUnit();
                state = 2; // We know there will not be an overlapping start code, so we can skip that test
                return writeBytes(pData,o,l);
/*--------------------------------------------------------------------------------------------------------------------*/
            } // switch
        }
    }
}
