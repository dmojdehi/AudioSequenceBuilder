//
//  SubSegmentBuilderSound.m
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilderSound.h"
#import "SubSegmentBuilderContainer.h"
#import "AudioSequenceBuilder.h"
#import "DDXMLElement.h"
#import <AVFoundation/AVFoundation.h>

const double kFadeOutDuration = 2.0;
const double kFadeInDuration = 0.1;

static NSMutableDictionary *sAudioTracksByName = nil;


@interface LoopLogic : NSObject
{
	LoopToFitParent mLoopToFitParent;
	double mInitialWritePos;
	double mNextWritePos;
	int mWriteCount;
	
	SubSegmentBuilderContainer *mParentNotRetained;
}
@property (nonatomic,readonly) LoopToFitParent loopMode;
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer *)parent;

-(void)begin;
-(double)computeStartOffsetForFitToEnd:(double)duration;
-(void)wroteSegment:(NSString*)filename dur:(double)duration;

-(bool)more;
-(double)moreRemaining;
@end

@interface SubSegmentBuilderSound()
@property (nonatomic, strong) NSString *filename;
@property (nonatomic, strong) LoopLogic *loopLogic;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, assign) double volume;
@property (nonatomic, assign) double speed;
@property (nonatomic, assign) double markIn;
@property (nonatomic, assign) double markOut;
@property (nonatomic, assign) BOOL isNavigable;

+(NSURL *)findAudioFileOfNames:(NSArray *)filenames;
@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderSound
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		DDXMLNode *filenameNode = [elem attributeForName:@"file"];
		_filename = [[filenameNode stringValue] copy];
		
		// inserts a sound, using the given parameters
		// fish out our optional arguments
		//DDXMLNode *fadeInNode = [elem attributeForName:@"markIn"];
		//DDXMLNode *fadeOutNode = [elem attributeForName:@"markOut"];
		DDXMLNode *markInNode = [elem attributeForName:@"markIn"];
		DDXMLNode *markOutNode = [elem attributeForName:@"markOut"];
		
		_loopLogic = [[LoopLogic alloc]initWithElem:elem inContainer:parent];
		
		DDXMLNode *volumeNode = [elem attributeForName:@"volume"];
		_volume = 1.0;
		if(volumeNode)
		{
			NSString *volumeStr = [volumeNode stringValue];
			_volume = [volumeStr doubleValue];
		}
		
		// a custom playback speed?
		DDXMLNode *playbackSpeedAttr = [elem attributeForName:@"speed"];
		_speed = 1.0;
		if(playbackSpeedAttr)
		{
			NSString *speedStr = [playbackSpeedAttr stringValue];
			_speed = [speedStr doubleValue];
		}
		
		// should this insertion time be used in our next/prev map?
		// (default is *true*!)
		_isNavigable = true;
		DDXMLNode *navigableNode = [elem attributeForName:@"navigable"];
		if(navigableNode)
		{
			_isNavigable = [[navigableNode stringValue] boolValue];
		}
		
		// if we have both mark in & mark out, with **sample*** offsets
		// try to load the pre-cut files instead (to save time)
		NSURL *assetUrl = nil;
		// see if a pre-cut file is there
		if(markInNode && markOutNode)
		{
			if([[markInNode stringValue] rangeOfString:@"#"].length > 0)
			{
				NSString *markInStr = [[[markInNode stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""]stringByReplacingOccurrencesOfString:@"," withString:@""];
				NSString *markOutStr = [[[markOutNode stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""]stringByReplacingOccurrencesOfString:@"," withString:@""];
				int markInSample = [markInStr intValue];
				int markOutSample = [markOutStr intValue];
				
				NSString *filenameOfTrimmedMedia = [NSString stringWithFormat: @"%@-%d-%d", self.filename, markInSample, markOutSample];
				assetUrl = [SubSegmentBuilderSound findAudioFile:filenameOfTrimmedMedia];
				if(assetUrl)
				{
					// we got one!
					// be sure to use this whole file, not the cut points
					markInNode = nil;
					markOutNode = nil;
				}
				
		    }
		}
		if(!assetUrl)
			assetUrl = [SubSegmentBuilderSound findAudioFile:self.filename];
		
		
		if(!assetUrl)
			[NSException raise:@"Unable to find file" format:@"line %d: File '%@', wasn't found (looked for both .mp3 and .m4a)", 0/*elem.line*/, self.filename];
		
		
		
		// have we already loaded this asset?  just reuse it, please!
		self.asset = sAudioTracksByName[[assetUrl absoluteString]];
		if(self.asset)
		{
			NSLog(@"... loaded asset tracks from cache!");
		}
		else
		{
			NSLog(@"... loading asset tracks (not from cache)");
			self.asset = [AVURLAsset URLAssetWithURL:assetUrl options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES} ];
			sAudioTracksByName[[assetUrl absoluteString]] = self.asset;
			//self.asset = [AVURLAsset URLAssetWithURL:assetUrl options:nil];
		}
		if(!self.asset)
		{
			[NSException raise:@"Unable to open file" format:@"line %d: File '%@.mp3' couldn't be opened", 0/*elem.line*/, self.filename];
		}
		
		
		// determine the mark in & out
		_markIn = 0.0;
		//CMTime markIn = kCMTimeZero;
		if(markInNode)
		{
			_markIn =  [AudioSequenceBuilder parseTimecode:[markInNode stringValue]];
			//markIn = CMTimeMakeWithSeconds(mMarkIn, 44100);
		}
		
		if(markOutNode)
		{
			_markOut = [AudioSequenceBuilder parseTimecode:[markOutNode stringValue]];
		}
		else
		{
			CMTime dur = self.asset.duration;
#if DEBUG
			// double check that we can get the value now
			NSString *filename = [assetUrl lastPathComponent];
			NSError *err = nil;
			AVKeyValueStatus status = [self.asset statusOfValueForKey:@"duration" error:&err];
			if(status != AVKeyValueStatusLoaded)
			{
				NSString *warningMessage = [NSString stringWithFormat:@"The duration of file '%@' wasn't available immediately  (status = %d).  It will play incorrectly.", filename, status];
				NSLog(@"%@", warningMessage);
				UIAlertView *alert= [[UIAlertView alloc] initWithTitle:@"Audio slow to load!" message:warningMessage delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles: nil];
				[alert	show];
			}
			
			BOOL readable = self.asset.isReadable;
			BOOL composable = self.asset.isComposable;
			BOOL playable = self.asset.isPlayable;
			NSLog(@"... loaded file '%@', readable:%d, composable:%d, playable:%d, duration: %.4f", filename, readable, composable, playable, CMTimeGetSeconds(dur));
#endif
			
			
			_markOut = CMTimeGetSeconds(dur);
		}
		
		// loop to fit elements *don't* extend their parents duration
		if(self.loopLogic.loopMode == kLoopNone)
		{
			double speedMultiplier = 1.0/ self.speed;
			[parent addToMediaAndFixedPadding: (_markOut - _markIn) * speedMultiplier];
		}
	}
	return self;
}


#if qSimplifiedStack
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder
#else
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)compositionAudioTrack andVideoTrack:(AVMutableCompositionTrack*)compositionVideoTrack
#endif
{
	bool hasVideo = [[self.asset tracksWithMediaType:AVMediaTypeVideo] count] > 0;
	
	
#if qSimplifiedStack
	AVMutableCompositionTrack *compositionAudioTrack = [builder.trackStack getOrCreateNextAudioTrack];
	AVMutableCompositionTrack *compositionVideoTrack = nil;
	if(hasVideo)
		compositionVideoTrack = [builder.trackStack getOrCreateNextVideoTrack];
#endif
		
#if DEBUG
	int trackID  = compositionAudioTrack.trackID;
	NSLog(@"2nd pass: Adding sound: '%@' to track id:%d (at pos: %f)",self.filename, trackID, self.parent.nextWritePos);
#endif
	
	// find the destination tracks
	
	//	if([self.filename compare:@"BG_Reflective_Peace"] == 0)
	//	{
	//		int z = 0;
	//	}
	AVAssetTrack *sourceAudioTrack = [self.asset tracksWithMediaType:AVMediaTypeAudio][0];
	if(!sourceAudioTrack)
	{
		NSLog(@"...  FAILED to add sound.  There we no audio tracks in the asset");
		[NSException raise:@"Asset had no audio" format:@"line %d: File '%@.mp3' had no audio tracks", 0 /*mElement.line*/, self.filename];
	}
	
	AVAssetTrack *sourceVideoTrack = nil;
	if(hasVideo)
	{
		sourceVideoTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo][0];
		if(!sourceVideoTrack)
		{
			NSLog(@"...  FAILED to add video.  There we no video tracks in the asset");
			//[NSException raise:@"Asset had no video" format:@"line %d: File '%@' had no video tracks", 0 /*mElement.line*/, self.filename];
		}
	}
	
	// make an audio mix for this track (actually an AVAudioMixInputParameters
	//AVMutableAudioMixInputParameters *audioMix = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:sourceAudioTrack];
	//[audioMix setVolumeRampFromStartVolume:0.0 toEndVolume:1.0 timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(5.0, 44100))];
	// - (void)setVolumeRampFromStartVolume:(float)startVolume toEndVolume:(float)endVolume timeRange:(CMTimeRange)timeRange;
	//[theAudioMixParameters addObject:audioMix];
	
	
	NSError *err = nil;
	
	// parent span as a timerange
	//CMTimeRange parentDuration = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(self.parent.durationOfMediaAndFixedPadding, 44100));
	
	[self.loopLogic begin];
	
	// the time to fill
	//CMTime endingWritePos = CMTimeMakeWithSeconds(self.parent.optionalFixedDuration, 44100);
	//		CMTime desiredTotalDuration = CMTimeMakeWithSeconds(self.parent.durationOfMediaAndFixedPadding, 44100);
	//		CMTimeRange rangeToFill = CMTimeRangeMake(initialWritePos, desiredTotalDuration);
	
	CMTime markIn = CMTimeMakeWithSeconds(_markIn, 44100);
	CMTime markOut = CMTimeMakeWithSeconds(_markOut, 44100);
	
	
	// if we're fitting to the end, the first time we usually start well past the markin
	double markInOutTimeRangeDurationInSeconds = _markOut - _markIn;
	double initialOffsetFromMarkIn = [self.loopLogic computeStartOffsetForFitToEnd:markInOutTimeRangeDurationInSeconds];
	CMTime markInToUse = CMTimeAdd(markIn, CMTimeMakeWithSeconds(initialOffsetFromMarkIn,44100 ) );
	
	
	// loop as long as the next write pos is less than the final pos
	while([self.loopLogic more])
	{
		CMTime insertionPos = CMTimeMakeWithSeconds(self.parent.nextWritePos, 44100);
		CMTime markOutToUse = markOut;
		double moreRemaining = [self.loopLogic moreRemaining];

		if(moreRemaining < kFadeOutDuration + kFadeInDuration)
		{
			// we get here if there's just too little time to fade in and out!
			// so don't even write the audio segment!
#if DEBUG
			NSLog(@"... remaining duration is too short (%.2f), *not* adding the sound", moreRemaining);
#endif
			break;
		}

		// apply at the audio ramp for this clip

		AVMutableAudioMixInputParameters *audioEnvelope = [builder audioEnvelopeForTrack:compositionAudioTrack];
		//AVMutableAudioMixInputParameters *audioEnvelope = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionTrack];
		[audioEnvelope setVolume:self.volume atTime:insertionPos];

		// make the timerange in the source to use
		// (when fitting-to-end, the first time in the loop we may be offset)
		CMTimeRange sourceMarkInOutTimeRange = CMTimeRangeFromTimeToTime(markInToUse, markOutToUse);
		// (any subsequent loops will use the whole markIn-markOut
		markInToUse = markIn;
		
		// TODO don't write past the end time
		// limit the source range by the amount remaining in the output!
		if(self.loopLogic.loopMode != kLoopNone &&
		   (CMTimeGetSeconds(sourceMarkInOutTimeRange.duration) > moreRemaining) )
		{
			// we get here if a looping track needs to be truncated to fit a parent
			sourceMarkInOutTimeRange.duration = CMTimeMakeWithSeconds(moreRemaining, 44100);
			
			// also, fade out over the last second or so
			CMTime fadeOutBeginTime = CMTimeAdd( insertionPos, CMTimeMakeWithSeconds(moreRemaining - kFadeOutDuration, 44100) );
			CMTime fadeOutDuration = CMTimeMakeWithSeconds( MIN( kFadeOutDuration, moreRemaining - kFadeInDuration), 44100 );
			CMTimeRange fadeOutRange = CMTimeRangeMake(fadeOutBeginTime, fadeOutDuration);

#if DEBUG
			NSLog(@"...  applying fade out vol:%.1f to 0, at time %.4f (duration %.4f)", self.volume, CMTimeGetSeconds(fadeOutRange.start), CMTimeGetSeconds(fadeOutRange.duration));
#endif

			@try {
				[audioEnvelope setVolumeRampFromStartVolume:self.volume toEndVolume:0.0 timeRange:fadeOutRange];
				
			}
			@catch (NSException *exception) {
				NSString *fadeOutDesc = (__bridge NSString *) CMTimeRangeCopyDescription(kCFAllocatorDefault, fadeOutRange);
				// dump the existing
				NSLog(@"FAILURE!! Error writing envelope for track %@ at time range %@", compositionAudioTrack, fadeOutDesc);
				
			}

			//[audioMix setVolumeRampFromStartVolume:0.0 toEndVolume:volume timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(5.0, 44100))];
		}
		else
		{
			// set the volume for the end, too
			CMTime time = CMTimeAdd( insertionPos, sourceMarkInOutTimeRange.duration);
			NSLog(@"...  applying end vol vol:%.1f to 0, at time %.4f", self.volume, CMTimeGetSeconds(time));
			[audioEnvelope setVolume:self.volume atTime:CMTimeAdd( insertionPos, sourceMarkInOutTimeRange.duration)];
		}

		
		// if this sound is to be used in next/prev navigation, add it now
		if(builder && self.isNavigable)
		{
			[builder addNavigationTime:self.parent.nextWritePos];
			
		}
		
		NSError *errA, *errV;
		BOOL successA = [compositionAudioTrack insertTimeRange:sourceMarkInOutTimeRange
												 ofTrack:sourceAudioTrack
												  atTime:insertionPos
												   error:&errA];
		BOOL successV = YES;
		if(hasVideo && sourceVideoTrack && compositionVideoTrack)
		{
			successV = [compositionVideoTrack insertTimeRange:sourceMarkInOutTimeRange
												 ofTrack:sourceVideoTrack
												  atTime:insertionPos
												   error:&errV];
		}
		
		if(!successA || !successV || errA || errV)
		{
			NSLog(@"...  FAILED to add sound at %f.  Error was: '%@'", self.parent.nextWritePos, [err localizedDescription]);
			break; // no more writing...
		}
		else
		{
			// we succeeded!
			
			// apply any custom playback speed
			double amountJustAdded = CMTimeGetSeconds( sourceMarkInOutTimeRange.duration );
			if(self.speed != 1.0)
			{
				CMTimeRange insertedTime = CMTimeRangeMake(insertionPos, sourceMarkInOutTimeRange.duration);
				CMTime newDuration = CMTimeMultiplyByFloat64(sourceMarkInOutTimeRange.duration, 1.0 / self.speed);
				
				[compositionAudioTrack scaleTimeRange:insertedTime toDuration:newDuration];
				if(hasVideo)
					[compositionVideoTrack scaleTimeRange:insertedTime toDuration:newDuration];
				
				// the added amount is actually much longer
				amountJustAdded = CMTimeGetSeconds(newDuration);
			}
			
			// update the nextwrite cursor (for left-justified siblings)
			
			// accumulates time into parent's nextWritePos
			[self.loopLogic wroteSegment:self.filename dur:amountJustAdded];
			
			NSLog(@"...  added sound (new pos: %f)", self.parent.nextWritePos);
		}
	

	}
}
+(NSURL *)findAudioFile:(NSString *)filename
{
	return [SubSegmentBuilderSound findAudioFileOfNames:@[filename]];
	
}

+(NSURL *)findAudioFileOfNames:(NSArray *)filenames
{
	NSArray *extensions = @[@"aif", @"aiff", @"m4a", @"mp3", @"m4v" ];
	
	
	for(NSString *filename in filenames)
	{

		
		for(NSString *extension in extensions)
		{
			NSURL *assetUrl = [[NSBundle mainBundle] URLForResource:filename withExtension:extension];
			if(assetUrl)
			{
				return assetUrl;
			}		
		}
	}
	
	return nil;
	
}
@end









@implementation LoopLogic
@synthesize loopMode = mLoopToFitParent;

-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer *)parent
{
	self = [super init];
	if(self)
	{
		if(!sAudioTracksByName)
			sAudioTracksByName= [[NSMutableDictionary alloc]init ];
		mWriteCount = 0;
		mParentNotRetained = parent;
		// loopToFitParent possible values:
		//	simple			--  A simple loop to fill. The end will have a fade out.
		//	loopWholeOnly	--  The segment will reapeat as many times as can fit in the parent evenly.
		//						it will *shorten* the parents fixed duration to match it's final duration!
		//	loopFromEnd		--	loops the given segment, but aligns the last loop to end at the parents end
		//						this is used by drum journey.  Notice that there is a brief crossfade across
		//						the loop end and beginning, where 1/10th of a second *after* the mark out is played under the mark-in
		//
		mLoopToFitParent = kLoopNone;
		DDXMLNode *loopToFitParentNode = [elem attributeForName:@"loopToFitParent"];
		if(loopToFitParentNode)
		{
			if([[loopToFitParentNode stringValue] compare:@"loopSimple" options:NSCaseInsensitiveSearch] == 0)
			{
				mLoopToFitParent = kLoopSimple;
			}
			else if([[loopToFitParentNode stringValue] compare:@"loopFromEnd" options:NSCaseInsensitiveSearch] == 0)
				mLoopToFitParent = kLoopFromEnd;
			else if([[loopToFitParentNode stringValue] compare:@"loopWholeOnly" options:NSCaseInsensitiveSearch] == 0)
				mLoopToFitParent = kLoopWholeOnly;
			else
			{
				[NSException raise:@"Unrecognized loopToFitParent option"  format:@"loopToFitParent didn't recognize option '%@', line %d", [loopToFitParentNode stringValue], 0/*loopToFitParentNode.line*/ ];
				
			}
			
			
		}
		
	}
	return self;
}
-(void)begin
{
	mInitialWritePos = mParentNotRetained.nextWritePos;
	//	while((mLoopToFitParent != kLoopNone) &&
	//		  localNextWritePos < finalWonkyWritePos);
	
}

// if we're fitting to the end, the first time we usually start well past the markin
-(double)computeStartOffsetForFitToEnd:(double)duration
{
	double initialOffsetFromMarkIn = 0.0;
	if(mLoopToFitParent == kLoopFromEnd)
	{
		double desiredDuration = [mParentNotRetained durationToFill];
		double amountOfMediaNeeded = fmod(desiredDuration, duration);
		initialOffsetFromMarkIn = duration - amountOfMediaNeeded;
	}
	
	return initialOffsetFromMarkIn;
}

-(void)wroteSegment:(NSString*)filename dur:(double)duration
{
	mParentNotRetained.nextWritePos += duration;
	mWriteCount++;
}

double kUnlimitedRemaining = 999999.9;

// returns the duration remaining
-(double)moreRemaining
{
	double remaining = 0.0;
	double parentDurationToFill = [mParentNotRetained durationToFill];
	if(mLoopToFitParent != kLoopNone)
	{
		double nextWritePos = mParentNotRetained.nextWritePos;
		remaining = mInitialWritePos + parentDurationToFill - nextWritePos;
		if(remaining < 0.0)
			remaining = 0.0;
	}
	else
	{
		// non-looping elements should write only once
		if(mWriteCount == 0)
		{
			if(mParentNotRetained && [mParentNotRetained hasAnyFixedDurations])
				remaining = parentDurationToFill;
			else
				remaining = kUnlimitedRemaining;
		}
		else
		{
			// we're non-looping, and have already written
			remaining = 0;
		}
	}
	
	return remaining;
	
}

-(bool)more
{
#if 1
	if([self moreRemaining] > 0.0)
		return true;
	else
		return false;
	//	if(mParentNotRetained &&
	//	   [mParentNotRetained hasAnyFixedDurations] &&
	//	   [self moreRemaining] > 0.0 )
	//	   return true;
	//   else
	//	   return false;
#else
	bool more= false;
	if(mLoopToFitParent != kLoopNone)
	{
		double parentDurationToFill = [mParentNotRetained durationToFill];
		double nextWritePos = mParentNotRetained.nextWritePos;
		if(nextWritePos < mInitialWritePos + parentDurationToFill )
			more = true;
		else
			more = false;
	}
	else
	{
		// non-looping elements should write only once
		if(mWriteCount == 0)
			more = true;
	}
	
	return more;
#endif
}
@end
