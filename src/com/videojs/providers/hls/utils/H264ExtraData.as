package com.videojs.providers.hls.utils{

    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public class H264ExtraData
    {
        private var sps:Array = new Array;
        private var pps:Array = new Array;

        public function H264ExtraData()
        {}

        public function addSPS():ByteArray
        {
            var tmp:ByteArray = new ByteArray;
             sps.push(tmp);
             return tmp;
        }

        public function addPPS():ByteArray
        {
            var tmp:ByteArray = new ByteArray;
             pps.push(tmp);
             return tmp;
        }
/*
        public function isSame(that:H264ExtraData):Boolean
        {
            var i:int; var j:int;
            if( this.sps.length != that.sps.length ||  this.pps.length != that.pps.length )
                return false;

            // SPS
            for(i = sps.length - 1 ; i >= 0 ; --i )
            {
                if ( this.sps[i].length != that.sps[i].length )
                    return false;

                for(j = sps[i].length - 1 ; j >= 0 ; --j )
                    if ( this.sps[i][j] !=  that.sps[i][j] )
                        return false;
            }

            // PPS
            for(i = pps.length - 1 ; i >= 0 ; --i )
            {
                if ( this.pps[i].length != that.pps[i].length )
                    return false;

                for(j = sps[i].length - 1 ; j >= 0 ; --j )
                    if ( this.pps[i][j] !=  that.pps[i][j] )
                        return false;
            }

            return true;
        }
*/
        public function extraDataExists():Boolean
        {
            return 0 < sps.length
        }


        private function scaling_list(sizeOfScalingList:int, expGolomb:ExpGolomb):void
        {
            var lastScale:int = 8;
            var nextScale:int = 8;
            for( var j:int = 0; j < sizeOfScalingList; ++j )
            {
                if ( 0 != nextScale )
                {
                    var delta_scale:int = expGolomb.readExpGolomb();
                    nextScale = ( lastScale + delta_scale + 256 ) % 256;
                    //useDefaultScalingMatrixFlag = ( j = = 0 && nextScale = = 0 )
                }

                lastScale = ( nextScale == 0 ) ? lastScale : nextScale;
                // scalingList[ j ] = ( nextScale == 0 ) ? lastScale : nextScale;
                // lastScale = scalingList[ j ]
            }
        }

        private function getSps0Rbsp():ByteArray
        {
            // remove emulation bytes. Is this nesessary? is there ever emulation bytes in the SPS?
            var sps0:ByteArray = sps[0];
            sps0.position      = 1;
            var s:uint         = sps0.position;
            var e:uint         = sps0.bytesAvailable - 2;
            var rbsp:ByteArray = new ByteArray;
            for(var o:uint = s ; o < e ; )
            {
                if ( 3 != sps0[o+2] )
                    o += 3;
                else
                if( 0 != sps0[o+1] )
                    o += 2;
                else
                if( 0 != sps0[o+0] )
                    o += 1;
                else
                { // found emulation bytess
                    rbsp.writeShort(0x0000);

                    if ( o > s ) // If there are bytes to write, write them
                        sps0.readBytes( rbsp, rbsp.length, o-s );

                     // skip the emulation bytes
                    sps0.position += 3;
                    o = s = sps0.position;
                }
            }

            // copy any remaining bytes
            sps0.readBytes( rbsp, rbsp.length );
            sps0.position = 0;
            return rbsp;
        }

        public function metaDataTag(pts:uint):FlvTag
        {
            var tag:FlvTag = new FlvTag(FlvTag.METADATA_TAG);
            tag.dts = pts;
            tag.pts = pts;
            var expGolomb:ExpGolomb = new ExpGolomb( getSps0Rbsp() );

            var profile_idc:int = expGolomb.readUnsignedByte(); // profile_idc u(8)
            expGolomb.skipBits(16);// constraint_set[0-5]_flag, u(1), reserved_zero_2bits u(2), level_idc u(8)
            expGolomb.skipUnsignedExpGolomb() // seq_parameter_set_id

            if( profile_idc == 100 || profile_idc == 110 || profile_idc == 122 || profile_idc == 244 || profile_idc == 44 || profile_idc == 83 || profile_idc == 86 || profile_idc == 118 || profile_idc == 128 )
            {
                var chroma_format_idc:int = expGolomb.readUnsignedExpGolomb();
                if ( 3 == chroma_format_idc )
                    expGolomb.skipBits(1); // separate_colour_plane_flag
                expGolomb.skipUnsignedExpGolomb() // bit_depth_luma_minus8
                expGolomb.skipUnsignedExpGolomb()// bit_depth_chroma_minus8
                expGolomb.skipBits(1); // qpprime_y_zero_transform_bypass_flag
                if ( expGolomb.readBoolean() ) // seq_scaling_matrix_present_flag
                {
                    var imax:int = ( chroma_format_idc != 3 ) ? 8 : 12;
                    for(var i:int = 0 ; i < imax ; ++i)
                        if ( expGolomb.readBoolean() )// seq_scaling_list_present_flag[ i ]
                            if( i < 6 )
                                scaling_list( 16, expGolomb )
                            else
                                scaling_list( 64, expGolomb )
                }
            }

            expGolomb.skipUnsignedExpGolomb(); // log2_max_frame_num_minus4
            var pic_order_cnt_type:int = expGolomb.readUnsignedExpGolomb();

            if ( 0 == pic_order_cnt_type )
                expGolomb.readUnsignedExpGolomb(); //log2_max_pic_order_cnt_lsb_minus4
            else
            if ( 1 == pic_order_cnt_type )
            {
                expGolomb.skipBits(1); // delta_pic_order_always_zero_flag
                expGolomb.skipExpGolomb(); // offset_for_non_ref_pic
                expGolomb.skipExpGolomb(); // offset_for_top_to_bottom_field
                var num_ref_frames_in_pic_order_cnt_cycle:uint = expGolomb.readUnsignedExpGolomb();
                for(i = 0 ; i < num_ref_frames_in_pic_order_cnt_cycle ; ++i)
                    expGolomb.skipExpGolomb(); // offset_for_ref_frame[ i ]
            }

            expGolomb.skipUnsignedExpGolomb(); // max_num_ref_frames
            expGolomb.skipBits(1); // gaps_in_frame_num_value_allowed_flag
            var pic_width_in_mbs_minus1:int        = expGolomb.readUnsignedExpGolomb();
            var pic_height_in_map_units_minus1:int = expGolomb.readUnsignedExpGolomb();

            var frame_mbs_only_flag:int = expGolomb.readBits(1);
            if ( 0 == frame_mbs_only_flag )
                expGolomb.skipBits(1); // mb_adaptive_frame_field_flag

            expGolomb.skipBits(1); // direct_8x8_inference_flag
            var frame_cropping_flag:Boolean = expGolomb.readBoolean();
            if ( frame_cropping_flag )
            {
                var frame_crop_left_offset:int   = expGolomb.readUnsignedExpGolomb();
                var frame_crop_right_offset:int  = expGolomb.readUnsignedExpGolomb();
                var frame_crop_top_offset:int    = expGolomb.readUnsignedExpGolomb();
                var frame_crop_bottom_offset:int = expGolomb.readUnsignedExpGolomb();
            }

            var width:Number  = ((pic_width_in_mbs_minus1 +1)*16) - frame_crop_left_offset*2 - frame_crop_right_offset*2;
            var height:Number = ((2 - frame_mbs_only_flag)* (pic_height_in_map_units_minus1 +1) * 16) - (frame_crop_top_offset * 2) - (frame_crop_bottom_offset * 2);

            tag.writeMetaDataDouble("videocodecid", 7);
            tag.writeMetaDataDouble("width", width);
            tag.writeMetaDataDouble("height", height);
//            tag.writeMetaDataDouble("videodatarate", 0 );
//            tag.writeMetaDataDouble("framerate", 0);

            return tag;
        }

        public function extraDataTag(pts:uint):FlvTag
        {
            var tag:FlvTag = new FlvTag(FlvTag.VIDEO_TAG,true);
            tag.dts = pts;
            tag.pts = pts;

            tag.writeByte(0x01);// version
            tag.writeByte(sps[0][1]);// profile
            tag.writeByte(sps[0][2]);// compatibility
            tag.writeByte(sps[0][3]);// level
            tag.writeByte(0xFC | 0x03); // reserved (6 bits), NULA length size - 1 (2 bits)
            tag.writeByte(0xE0 | 0x01 ); // reserved (3 bits), num of SPS (5 bits)
            tag.writeShort( sps[0].length ); // data of SPS
            tag.writeBytes( sps[0] ); // SPS

            tag.writeByte( pps.length ); // num of PPS (will there ever be more that 1 PPS?)
            for(var i:uint = 0 ; i < pps.length ; ++i )
            {
                tag.writeShort( pps[i].length ); // 2 bytes for length of PPS
                tag.writeBytes( pps[i] ); // data of PPS
            }

            return tag;
        }
    }
}
