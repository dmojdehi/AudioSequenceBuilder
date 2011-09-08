

AudioSequenceBuilder
====================

A set of classes for assembling audio files into sophisticated AVFoundation sequences.

Say you have some audio files in your project that you'd like to play in sequence.  Simply feed an XML description of the sequence to AudioSequenceBuilder and it'll return a fully built AVPlayer, ready to play with AVFoundation!

Here's an example from the demo project.  It loads the built-in audio files (car-start.m4a, car-vroom.m4a, and car-crash.m4a):


	<seq >
		<sound file="car-start" />
		<sound file="car-vroom" />
		<sound file="car-crash" />
	</seq>


And in your Objective-C code:

		// load the builder
		AudioSequenceBuilder *builder = [[[AudioSequenceBuilder alloc] init ] autorelease];
		// load the document
		NSURL *docUrl = [[NSBundle mainBundle] URLForResource:@"Sample" withExtension:@"xml"];
		[builder loadDocument:docUrl];	

		// build it
		AVPlayer *player = [builder buildPlayer];
		self.builder = builder;
		
		// once it's ready, begin playback
		[self.player addObserverForKeyPath:@"status" task:^(id obj, NSDictionary *change) {

			AVPlayerStatus playerStatus = player.status;

			if(playerStatus == AVPlayerStatusReadyToPlay)
			{
				[player play];
			}
		}];




In addition to serial playback, sounds can play in the background with the `<par>` container.  Here's the example above with an added background music track:

	<par>
		<!-- the main sound sequence -->
		<seq >
			<sound file="car-start" />
			<sound file="car-vroom" />
			<sound file="car-crash" />
		</seq>
	
	
		<!-- the background sound -->
		<sound file="tension" />
	</par>



Add To Your Project
===============

The easiest way is to simply drag these core files into your XCode project:

	AudioSequenceBuilder.h
	AudioSequenceBuilder.m
	SubSegmentBuilder.h
	SubSegmentBuilder.m
	SubSegmentBuilderContainer.h
	SubSegmentBuilderContainer.m
	SubSegmentBuilderSilence.h
	SubSegmentBuilderSilence.m
	SubSegmentBuilderSound.h
	SubSegmentBuilderSound.m

You'll also need to add:

*	the [KissXML project](http://code.google.com/p/kissxml/)
	*	I use the KissXML parser because you can modify the XML after you load it, which is very handy
	*	You can use another parser, but you'll have to adjust the classnames in a few places.
*	Apple's AVFoundation & CoreMedia frameworks



Experimental Features
===============

Fixed duration
--------------

Specifies that a segment should last a given overall duration, fitting the sounds within appropriately.

Here's a 1 min, 25 sec clip.  Note that the car-crash sound will be delayed to play at the end:

	<seq duration="1:25.0000" >
		<sound file="car-start" />
		<sound file="car-vroom" />
		<padding ratio="1.0" />
		<sound file="car-crash" />
	</seq>

**Note:** 'duration' is treated as a minimum duration.  If the segment extends past the duration it isn't truncated.  This behavior may change in future versions.

**Note:** multiple `<padding>` sections work as you'd expect; you can have many of them and they add up then divide their `ratio` padding evenly.

Loop-to-fit
-----------
For background tracks that need to repeat to fit their parent:

	<par duration="1:25.0000" >
		<seq >
			<sound file="car-start" />
			<sound file="car-vroom" />
			<sound file="car-crash" />
		</seq>
	
		<sound file="tension" loopToFitParent="loopSimple" />
	</par>

The background 'tension' track will repeat as many times as needed the parent `par`.


FF & Rew support
-----------

All `<sound>`s are treated as navigable chapter markers.  That is, you can ff & rew to their beginnings.  If you include a sound that *shouldn't* be treated as navigable, such as background sounds, just mark them as `navigable='false'`. 
	
Like so:
	
	<sound file="tension" navigable="false" />
	
	
