var uid = 0;

function createSWF(e){

  var flashvars = {
    readyFunction: "onSWFReady",
    eventProxyFunction: "onSWFEvent",
    errorEventProxyFunction: "onSWFErrorEvent",
    src: "http://video-js.zencoder.com/oceans-clip.mp4",
    autoplay: false,
    preload: 'auto',
    poster: "http://video-js.zencoder.com/oceans-clip.png"
  };

  var params = {
    allowScriptAccess: "always",
    bgcolor: "#000000"
  };

  var attributes = {
    id: "videoPlayer"+uid,
    name: "videoPlayer"+uid
  };

  swfobject.embedSWF("../dist/video-js.swf", "videoPlayer"+uid, "100%", "100%", "10.3", "", flashvars, params, attributes);
}

function swfSetup(){
  stop();

  window.onSWFReady = $.proxy(function(swfID){
    // console.log("onSWFReady", swfID);
    this.box = document.getElementById(swfID+"_box");
    this.swf = document.getElementById(swfID);
    start();
  }, this);
  
  window.onSWFEvent = function(swfID, eventName){
    console.log("onSWFEvent", swfID, eventName);

    // Triggering on outer div because triggering in object wasn't working for some reason.
    $("#"+swfID+"_box").trigger(eventName);
  };

  // Bind events to outer box.
  this.on = function(eventName, fn){
    $(this.box).bind(eventName, $.proxy(fn, this));
  }

  // Custom methods for failing a test after a certain amount of time
  this.failIn = function(ms){ this.failOutID = setTimeout(function(){ start(); }, ms); };
  this.cancelFail = function(){ clearTimeout(this.failOutID); };

  // Embed new box and placeholder for swf
  uid++;
  var id = "videoPlayer"+uid;
  $("#custom-fixture").append("<div id='"+id+"_box' class='box'><div id='"+id+"'></div></div>")

  createSWF();
}

function swfTeardown(){
  swfobject.removeSWF(this.swf.id);
  delete this.swf;
  $("#custom-fixture").html("");
}


module("SWF Tests", {
  setup: swfSetup,
  teardown: swfTeardown
});

test("SWF Set Up & Ready", 2, function() {
  ok(this.swf, "Player has been set up and is ready.");
  ok(typeof this.swf.vjs_play == 'function', "API Methods are available on ready.");
});

// Pause after playing event
test("Pause After 'playing' Event", 1, function() {
  stop();

  // Wait for playing even then call pause()
  this.on("playing", function(){
    this.swf.vjs_pause();
  });

  this.on("pause", function(){
    ok(true, "Player pauses.");

    this.cancelFail();
    start();
  });

  // Fail after 5 seconds if it doesn't work
  this.failIn(3000);

  this.swf.vjs_play();
});


// Play Method
test("Play", 1, function() {
  stop();

  this.on("playing", function(){
    ok(true, "Player plays.");
    start();
  });

  this.swf.vjs_play();
});

// 'seeked' event
// Commented-out as this only works intermittently.  Sometimes the "seeked"
// event doesn't happen
/*test("Seeked event fires after time change", 1, function() {
  stop();
  this.on("loadeddata", function(){
    this.swf.vjs_pause();
    this.ct = this.swf.vjs_getProperty("currentTime");

    this.on("seeked", function(){

      ok(this.ct != this.swf.vjs_getProperty("currentTime"), "currentTime changed");
      start();
    });

    this.swf.vjs_setProperty("currentTime", 30);
  });

  this.swf.vjs_play();
});
*/

// Commented out for unknown reasons...

// /* Methods
// ================================================================================ */
// module("API Methods", {
//   setup: playerSetup,
//   teardown: playerTeardown
// });
// 
// function failOnEnded() {
//   this.player.one("ended", _V_.proxy(this, function(){
//     start();
//   }));
// }
// 
// // Play Method
// test("play()", 1, function() {
//   stop();
// 
//   this.player.one("playing", _V_.proxy(this, function(){
//     ok(true);
//     start();
//   }));
// 
//   this.player.play();
// 
//   failOnEnded.call(this);
// });
// 
// // Pause Method
// test("pause()", 1, function() {
//   stop();
// 
//   // Flash doesn't currently like calling pause immediately after 'playing'.
//   this.player.one("timeupdate", _V_.proxy(this, function(){
// 
//     this.player.pause();
// 
//   }));
// 
//   this.player.addEvent("pause", _V_.proxy(this, function(){
//     ok(true);
//     start();
//   }));
// 
//   this.player.play();
// });
// 
// // Paused Method
// test("paused()", 2, function() {
//   stop();
// 
//   this.player.one("timeupdate", _V_.proxy(this, function(){
//     equal(this.player.paused(), false);
//     this.player.pause();
//   }));
// 
//   this.player.addEvent("pause", _V_.proxy(this, function(){
//     equal(this.player.paused(), true);
//     start();
//   }));
// 
//   this.player.play();
// });
// 
// test("currentTime()", 1, function() {
//   stop();
// 
//   // Try for 3 time updates, sometimes it updates at 0 seconds.
//   // var tries = 0;
// 
//   // Can't rely on just time update because it's faked for Flash.
//   this.player.one("loadeddata", _V_.proxy(this, function(){
// 
//     this.player.addEvent("timeupdate", _V_.proxy(this, function(){
// 
//       if (this.player.currentTime() > 0) {
//         ok(true, "Time is greater than 0.");
//         start();
//       } else {
//         // tries++;
//       }
// 
//       // if (tries >= 3) {
//       //   start();
//       // }
//     }));
// 
//   }));
//   
//   this.player.play();
// });
// 
// 
// test("currentTime(seconds)", 2, function() {
//   stop();
// 
//   // var afterPlayback = _V_.proxy(this, function(){
//   //   this.player.currentTime(this.player.duration() / 2);
//   // 
//   //   this.player.addEvent("timeupdate", _V_.proxy(this, function(){
//   //     ok(this.player.currentTime() > 0, "Time is greater than 0.");
//   //     
//   //     this.player.pause();
//   //     
//   //     this.player.addEvent("timeupdate", _V_.proxy(this, function(){
//   //       ok(this.player.currentTime() == 0, "Time is 0.");
//   //       start();
//   //     }));
//   // 
//   //     this.player.currentTime(0);
//   //   }));
//   // });
// 
//   // Wait for Source to be ready.
//   this.player.one("loadeddata", _V_.proxy(this, function(){
// 
//     _V_.log("loadeddata", this.player);
//     this.player.currentTime(this.player.duration() - 1);
// 
//   }));
//   
//   this.player.one("seeked", _V_.proxy(this, function(){
// 
//     _V_.log("seeked", this.player.currentTime())
//     ok(this.player.currentTime() > 1, "Time is greater than 1.");
// 
//     this.player.one("seeked", _V_.proxy(this, function(){
//       
//       _V_.log("seeked2", this.player.currentTime())
// 
//       ok(this.player.currentTime() <= 1, "Time is less than 1.");
//       start();
// 
//     }));
// 
//     this.player.currentTime(0);
// 
//   }));
// 
// 
//   this.player.play();
// 
//   // this.player.one("timeupdate", _V_.proxy(this, function(){
//   // 
//   //   this.player.currentTime(this.player.duration() / 2);
//   // 
//   //   this.player.one("timeupdate", _V_.proxy(this, function(){
//   //     ok(this.player.currentTime() > 0, "Time is greater than 0.");
//   // 
//   //     this.player.pause();
//   //     this.player.currentTime(0);
//   // 
//   //     this.player.one("timeupdate", _V_.proxy(this, function(){
//   // 
//   //       ok(this.player.currentTime() == 0, "Time is 0.");
//   //       start();
//   // 
//   //     }));
//   // 
//   //   }));
//   // 
//   // 
//   // }));
// 
// });
// 
// /* Events
// ================================================================================ */
// module("API Events", {
//   setup: playerSetup,
//   teardown: playerTeardown
// });
// 
// var playEventList = []
// 
// // Test all playback events
// test("Initial Events", 11, function() {
//   stop(); // Give 30 seconds to run then fail.
// 
//   var events = [
//     // "loadstart" // Called during setup
//     "play",
//     "playing",
// 
//     "durationchange",
//     "loadedmetadata",
//     "loadeddata",
// 
//     "progress",
//     "timeupdate",
// 
//     "canplay",
//     "canplaythrough",
// 
//     "pause",
//     "ended"
//   ];
// 
//   // Add an event listener for each event type.
//   for (var i=0, l=events.length; i<l; i++) {
//     var evt = events[i];
//     
//     // Bind player and event name to function so event name value doesn't get overwritten.
//     this.player.one(evt, _V_.proxy({ player: this.player, evt: evt }, function(){
//       ok(true, this.evt);
// 
//       // Once we reach canplaythrough, pause the video and wait for 'paused'.
//       if (this.evt == "canplaythrough") {
//         this.player.pause();
//       
//       // After we've paused, go to the end of the video and wait for 'ended'.
//       } else if (this.evt == "pause") {
//         this.player.currentTime(this.player.duration() - 1);
// 
//         // Flash has an issue calling play too quickly after currentTime. Hopefully we'll fix this.
//         setTimeout(this.player.proxy(function(){
//           this.play();
//         }), 250);
// 
//       // When we reach ended, we're done. Continue with the test suite.
//       } else if (this.evt == "ended") {
//         start();
//       }
//     }));
//   }
// 
//   this.player.play();
// });