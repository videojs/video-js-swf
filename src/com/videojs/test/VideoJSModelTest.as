package com.videojs.test
{
	import org.flexunit.Assert;
	import com.videojs.VideoJSModel;
	
	public class VideoJSModelTest
	{		
		[Test]
		public function test_backgroundColor():void
		{
			VideoJSModel.getInstance().backgroundColor = -1;
			Assert.assertEquals(0, VideoJSModel.getInstance().backgroundColor);
		
			VideoJSModel.getInstance().backgroundColor = 5;
			Assert.assertEquals(5, VideoJSModel.getInstance().backgroundColor);
			
			VideoJSModel.getInstance().backgroundColor = 0;
			Assert.assertEquals(0, VideoJSModel.getInstance().backgroundColor);		
		}
		
		[Test]
		public function test_volume():void
		{
			VideoJSModel.getInstance().volume = -1;
			Assert.assertEquals(1, VideoJSModel.getInstance().volume);

			VideoJSModel.getInstance().volume = 2;
			Assert.assertEquals(1, VideoJSModel.getInstance().volume);

			VideoJSModel.getInstance().volume = 0.5;
			Assert.assertEquals(0.5, VideoJSModel.getInstance().volume);
		}
	}
}