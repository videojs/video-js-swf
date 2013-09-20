package com.videojs.providers.hls.utils {

    import com.videojs.utils.Console;

    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public class SegmentParser {

        public function SegmentParser() {
            super();
        }

        // duration in seconds
        public function getFlvHeader(duration:Number = 0.0, audio:Boolean = true, video:Boolean = true):ByteArray {
            var head:ByteArray = new ByteArray();
            head.endian = Endian.BIG_ENDIAN;
            head.writeUTFBytes("FLV");
            head.writeByte(0x01); // version
            head.writeByte(( audio ? 0x04 : 0x00 ) | ( video ? 0x01 : 0x00 ));
            head.writeUnsignedInt(head.length + 4);
            head.writeUnsignedInt(0);

            if (0 < duration) {
                var onMetaData:FlvTag = new FlvTag(FlvTag.METADATA_TAG);
                onMetaData.pts = onMetaData.dts = 0;
                onMetaData.writeMetaDataDouble("duration", duration);
                head.writeBytes(onMetaData.finalize());
            }

            return head;
        }

        private var pmtPid:uint;
        private var streamBuffer:ByteArray = new ByteArray;

        private var videoPid:uint;
        private var h264Stream:H264Stream = new H264Stream;

        private var audioPid:uint;
        private var aacStream:AacStream = new AacStream;


        // TODO add more testing to make sure we dont walk past the end of a TS packet!
        private function parseTSPacket(pData:ByteArray):Boolean {
            var s:uint = pData.position;
            var o:uint = s;
            var e:uint = o + 188;

            // Don't look for a sync byte. We handle that in parseSegmentBinaryData()

            var pusi:Boolean = Boolean(pData[o + 1] & 0x40); // Payload Unit Start Indicator
            var pid:int = ( pData[o + 1] & 0x1F ) << 8 | pData[o + 2]; // PacketId
    //                var scflag:int   = ( pData[o+3] & 0xC0 ) >>> 6;
            var afflag:int = ( pData[o + 3] & 0x30 ) >>> 4;
    //                var cc:int       = ( pData[o+3] & 0x0F ); // Continuity Counter we could use this for sanity check, and corrupt stream detection
            o += 4; // Done with TS header

    //          var randomAccessIndicator:Boolean;
            if (afflag > 0x01) {   // skip most of the adaption field
                var aflen:uint = pData[o];
    //              if ( 0 < aflen ) { randomAccessIndicator = Boolean( ( pData[o] & 0x40 ) >>> 6 ); }
                o += aflen + 1;
            }

            if (0x0000 == pid) // always test for PMT first! (becuse other variables default to 0)
            {
                o += ( pusi ? 1 + pData[o] : 0 ); // if pusi is set we must skip X bytes (PSI pointer field)
                var patTableId:int = pData[o];
                // assert ( 0x00 == tableId )

                var patCurrentNextIndicator:Boolean = Boolean(pData[o + 5] & 0x01);
                if (patCurrentNextIndicator) {
                    var patSectionLength:uint = ( pData[o + 1] & 0x0F ) << 8 | pData[o + 2];
                    o += 8; // skip past PSI header

                    // We currently only support streams with 1 program
                    patSectionLength = ( patSectionLength - 9 ) / 4;
                    if (1 != patSectionLength) {
                        throw new Error("TS has more that 1 program");
                    }

    //                  if we ever support more that 1 program (unlikely) loop over them here
    //                  var programNumber:int =   pData[o+0]          << 8 | pData[o+1];
    //                  var programId:int     = ( pData[o+2] & 0x1F ) << 8 | pData[o+3];
                    pmtPid = ( pData[o + 2] & 0x1F ) << 8 | pData[o + 3];
                }

                // We could test the CRC here to detect corruption with extra CPU cost
            }
            else if (videoPid == pid || audioPid == pid) {
                if (pusi) { // comment out for speed
                    //if( 0x00 != pData[o+0] || 0x00 != pData[o+1] || 0x01 != pData[o+2] )
                    //{// look for PES start code
                    //    throw new Error("PES did not begin with start code");
                    //}

    //                  var sid:int  = pData[o+3]; // StreamID
                    var pesPacketSize:int = ( pData[o + 4] << 8 ) | pData[o + 5];
                    var dataAlignmentIndicator:Boolean = Boolean(( pData[o + 6] & 0x04) >>> 2);
                    var ptsDtsIndicator:int = ( pData[o + 7] & 0xC0) >>> 6;
                    var pesHeaderLength:int = pData[o + 8]; // TODO sanity check header length
                    o += 9; // Skip past PES header

                    // PTS and DTS are normially stored as a 33 bit number. ActionScript does not have a integer type larger than 32 bit
                    // BUT, we need to convert from 90ns to 1ms time scale anyway. so what we are going to do instead, is
                    // drop the least significant bit (the same as dividing by two) then we can divide by 45 (45 * 2 = 90) to get ms.
                    var pts:uint;
                    var dts:uint;
                    if (ptsDtsIndicator & 0x03) {
                        pts = ( pData[o + 0] & 0x0E ) << 28
                                | ( pData[o + 1] & 0xFF ) << 21
                                | ( pData[o + 2] & 0xFE ) << 13
                                | ( pData[o + 3] & 0xFF ) << 6
                                | ( pData[o + 4] & 0xFE ) >>> 2;
                        pts /= 45;
                        if (ptsDtsIndicator & 0x01) {// DTS
                            dts = ( pData[o + 5] & 0x0E ) << 28
                                    | ( pData[o + 6] & 0xFF ) << 21
                                    | ( pData[o + 7] & 0xFE ) << 13
                                    | ( pData[o + 8] & 0xFF ) << 6
                                    | ( pData[o + 9] & 0xFE ) >>> 2;
                            dts /= 45;
                        } else {
                            dts = pts;
                        }
                    }
                    o += pesHeaderLength; // Skip past "optional" portion of PTS header

                    if (videoPid == pid) // Stash this frame for future use. TODO assert(videoFrames.length<3)
                        h264Stream.setNextTimeStamp(pts, dts, dataAlignmentIndicator);
                    else if (audioPid == pid)
                        aacStream.setNextTimeStamp(pts, pesPacketSize, dataAlignmentIndicator);
                }

                if (audioPid == pid)
                    aacStream.writeBytes(pData, o, e - o);
                else if (videoPid == pid)
                    h264Stream.writeBytes(pData, o, e - o);
            }
            else if (pmtPid == pid) {
                // TODO sanity check pData[o]
                o += ( pusi ? 1 + pData[o] : 0 ); // if pusi is set we must skip X bytes (PSI pointer field)
                var pmtTableId:int = pData[o];
                // assert ( 0x02 == tableId )

                var pmtCurrentNextIndicator:Boolean = Boolean(pData[o + 5] & 0x01);
                if (pmtCurrentNextIndicator) {
                    audioPid = videoPid = 0;
                    var pmtSectionLength:uint = ( pData[o + 1] & 0x0F ) << 8 | pData[o + 2];
                    pmtSectionLength -= 13; // skip CRC and PSI data we dont care about
                    o += 12; // skip past PSI header and some PMT data
                    while (0 < pmtSectionLength) {
                        var streamType:int = pData[o + 0];
                        var elementaryPID:int = ( pData[o + 1] & 0x1F ) << 8 | pData[o + 2];
                        var ESInfolength:int = ( pData[o + 3] & 0x0F ) << 8 | pData[o + 4];
                        o += 5 + ESInfolength;
                        pmtSectionLength -= 5 + ESInfolength;

                        if (0x1B == streamType) {
                            if (0 != videoPid) {
                                throw new Error("Program has more than 1 video stream");
                            }
                            videoPid = elementaryPID;
                        }
                        else if (0x0F == streamType) {
                            if (0 != audioPid) {
                                throw new Error("Program has more than 1 audio Stream");
                            }
                            audioPid = elementaryPID;
                        }

                        // TODO add support for MP3 audio
                    }
                }
                // We could test the CRC here to detect corruption with extra CPU cost
            }
            else if (0x0011 == pid) {
            } // Service Description Table
            else if (0x1FFF == pid) {
            } // NULL packet
            else {
                Console.log("Unknown PID " + pid);
            }

            return true;
        }

        public function flushTags():void {
            h264Stream.finishFrame();
        }

        private var seekToKeyFrame:Boolean = false;

        public function doSeek():void {
            flushTags();
            aacStream.tags.length = 0;
            h264Stream.tags.length = 0;
            seekToKeyFrame = true;
        }

        public function tagsAvailable():int {
            if (true == seekToKeyFrame) {
                for (var i:uint = 0; i < h264Stream.tags.length && true == seekToKeyFrame; ++i)
                    if (h264Stream.tags[i].keyFrame)
                        seekToKeyFrame = false; // We found, a keyframe, stop seeking

                if (true == seekToKeyFrame) {// we didnt find a keyframe. yet
                    h264Stream.tags.length = 0;
                    return 0;
                }

                // TODO we MAY need to use dts, not pts
                h264Stream.tags = h264Stream.tags.slice(i);
                var pts:uint = h264Stream.tags[0].pts;

                // Remove any audio before the found keyframe
                while (0 < aacStream.tags.length && pts > aacStream.tags[0].pts)
                    aacStream.tags.shift();
            }


            return h264Stream.tags.length + aacStream.tags.length;
        }

        public function getNextTag():ByteArray {
            var tag:FlvTag; // return tags in approximate dts order
            if (0 == tagsAvailable())
                throw new Error("getNextTag() called when 0 == tagsAvailable()");

            if (0 < h264Stream.tags.length) {
                if (0 < aacStream.tags.length && aacStream.tags[0].dts < h264Stream.tags[0].dts)
                    tag = aacStream.tags.shift();
                else
                    tag = h264Stream.tags.shift();
            }
            else if (0 < aacStream.tags.length) {
                tag = aacStream.tags.shift();
            }
            else { // We dont have any tags available to return
                return new ByteArray();
            }

            return tag.finalize();
        }

        public function parseSegmentBinaryData(pData:ByteArray):void {
            // more info on ByteArray: http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/utils/ByteArray.html
            // To avoid an extra copy, we will stash overflow data, and only reconstruct the first packet
            // The rest of the packets will be parsed directly from pData
            pData.position = 0;
            if (0 < streamBuffer.length) {
                if (188 > pData.length + streamBuffer.length) {
                    streamBuffer.readBytes(pData, pData.length, streamBuffer.length);
                    return;
                }
                else {
                    var bytes:uint = 188 - streamBuffer.length;
                    pData.readBytes(streamBuffer, streamBuffer.length, bytes);
                    streamBuffer.position = 0;
                    parseTSPacket(streamBuffer);
                    streamBuffer.clear();
                }
            }

            for (; ;) // loop forever
            {
                // Make sure we are TS aligned
                while (pData.bytesAvailable && 0x47 != pData[pData.position])
                    pData.position++; // If there is no sync byte skip forward until we find one
                // TODO if we find a sync byte, look 188 bytes in the future (if possible)
                // If there is not a sync byte there, keep looking

                if (188 <= pData.bytesAvailable) {
                    var position:int = pData.position;

                    if (parseTSPacket(pData))
                        pData.position = position + 188;
                    else
                        pData.position++;
                    // If there was an error parsing a TS packet. it could be because we are not TS packet aligned
                    // Step one forward by one byte and alloe teh code above to find the next

                } else {
                    // if there are bytes remaining, save them for next time
                    if (pData.bytesAvailable) // still
                        streamBuffer.writeBytes(pData, pData.position, pData.bytesAvailable);

                    return;
                }
            }
        }
    }
}
