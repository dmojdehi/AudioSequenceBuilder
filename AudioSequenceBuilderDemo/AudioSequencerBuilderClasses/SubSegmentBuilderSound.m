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
@implementation LoopLogic
@synthesize loopMode = mLoopToFitParent;

static NSMutableDictionary *sAudioTracksByName = nil;

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

@interface SubSegmentBuilderSound(Internal)
+(NSURL *)findAudioFileOfNames:(NSArray *)filenames;
@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderSound
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		DDXMLNode *filenameNode = [elem attributeForName:@"file"];
		mFilename = [[filenameNode stringValue] copy];
		
		// inserts a sound, using the given parameters
		// fish out our optional arguments
		//DDXMLNode *fadeInNode = [elem attributeForName:@"markIn"];
		//DDXMLNode *fadeOutNode = [elem attributeForName:@"markOut"];
		DDXMLNode *markInNode = [elem attributeForName:@"markIn"];
		DDXMLNode *markOutNode = [elem attributeForName:@"markOut"];
		
		mLoopLogic = [[LoopLogic alloc]initWithElem:elem inContainer:parent];
		
		DDXMLNode *volumeNode = [elem attributeForName:@"volume"];
		mVolume = 1.0;
		if(volumeNode)
		{
			NSString *volumeStr = [volumeNode stringValue];
			mVolume = [volumeStr doubleValue];
		}
		
		// should this insertion time be used in our next/prev map?
		// (default is *true*!)
		mIsNavigable = true;
		DDXMLNode *navigableNode = [elem attributeForName:@"navigable"];
		if(navigableNode)
		{
			mIsNavigable = [[navigableNode stringValue] boolValue];
		}
		
		// if we have both mark in & mark out, with **sample*** offsets
		// try to load the pre-cut files instead (to save time)
#if 1
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
				
				NSString *filenameOfTrimmedMedia = [NSString stringWithFormat: @"%@-%d-%d", mFilename, markInSample, markOutSample];
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
			assetUrl = [SubSegmentBuilderSound findAudioFile:mFilename];
		
#else
		NSMutableArray *filenamesToLookFor = [[[NSMutableArray alloc]init ]autorelease];
		if(markInNode && markOutNode)
		{
			if([[markInNode stringValue] rangeOfString:@"#"].length > 0)
			{
				NSString *markInStr = [[markInNode stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""];
				NSString *markOutStr = [[markOutNode stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""];
				int markInSample = [markInStr intValue];
				int markOutSample = [markOutStr intValue];
				
				NSString *filenameOfTrimmedMedia = [NSString stringWithFormat: @"%@-%d-%d", mFilename, markInSample, markOutSample];
				[filenamesToLookFor addObject:filenameOfTrimmedMedia];
		    }
		}
		
		// also look for the plain filename!
		[filenamesToLookFor addObject:mFilename];
		
		
		// find the file & load it
		NSURL *assetUrl = [SubSegmentBuilderSound findAudioFileOfNames:filenamesToLookFor];
#endif
		
		if(!assetUrl)
			[NSException raise:@"Unable to find file" format:@"line %d: File '%@', wasn't found (looked for both .mp3 and .m4a)", 0/*elem.line*/, mFilename];
		
		
		
		// have we already loaded this asset?  just reuse it, please!
		mAsset = [sAudioTracksByName objectForKey:[assetUrl absoluteString]];
		if(mAsset)
		{
			NSLog(@"... loaded asset tracks from cache!");
		}
		else
		{
			NSLog(@"... loading asset tracks (not from cache)");
			mAsset = [AVURLAsset URLAssetWithURL:assetUrl options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],
																   AVURLAssetPreferPreciseDurationAndTimingKey, nil] ];
			[sAudioTracksByName setObject:mAsset forKey:[assetUrl absoluteString]];
			//mAsset = [AVURLAsset URLAssetWithURL:assetUrl options:nil];
		}
		if(!mAsset)
		{
			[NSException raise:@"Unable to open file" format:@"line %d: File '%@.mp3' couldn't be opened", 0/*elem.line*/, mFilename];
		}
		
		
		// determine the mark in & out
		mMarkIn = 0.0;
		//CMTime markIn = kCMTimeZero;
		if(markInNode)
		{
			mMarkIn =  [AudioSequenceBuilder parseTimecode:[markInNode stringValue]];
			//markIn = CMTimeMakeWithSeconds(mMarkIn, 44100);
		}
		
		if(markOutNode)
		{
			mMarkOut = [AudioSequenceBuilder parseTimecode:[markOutNode stringValue]];
		}
		else
		{
			CMTime dur = mAsset.duration;			
#if DEBUG
			// double check that we can get the value now
			NSString *filename = [assetUrl lastPathComponent];
			NSError *err = nil;
			AVKeyValueStatus status = [mAsset statusOfValueForKey:@"duration" error:&err];
			if(status != AVKeyValueStatusLoaded)
			{
				NSString *warningMessage = [NSString stringWithFormat:@"The duration of file '%@' wasn't available immediately  (status = %d).  It will play incorrectly.", filename, status];
				NSLog(@"%@", warningMessage);
				UIAlertView *alert= [[UIAlertView alloc] initWithTitle:@"Audio slow to load!" message:warningMessage delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles: nil];
				[alert	show];
			}
			
			BOOL readable = mAsset.isReadable;
			BOOL composable = mAsset.isComposable;
			BOOL playable = mAsset.isPlayable;
			NSLog(@"... loaded file '%@', readable:%d, composable:%d, playable:%d, duration: %.4f", filename, readable, composable, playable, CMTimeGetSeconds(dur));
#endif
			
			
			mMarkOut = CMTimeGetSeconds(dur);
		}
		
		// loop to fit elements *don't* extend their parents duration
		if(mLoopLogic.loopMode == kLoopNone)
		{
			parent.durationOfMediaAndFixedPadding += mMarkOut - mMarkIn;
		}
	}
	return self;
}


-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoTrack:(AVMutableCompositionTrack*)compositionTrack
{	
#if DEBUG 
	int trackID  = compositionTrack.trackID;
	NSLog(@"2nd pass: Adding sound: '%@' to track id:%d (at pos: %f)",mFilename, trackID, mParent.nextWritePos);
#endif
	
	//	if([mFilename compare:@"BG_Reflective_Peace"] == 0)
	//	{
	//		int z = 0;
	//	}
	AVAssetTrack *sourceAudioTrack = [[mAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
	if(!sourceAudioTrack)
	{
		NSLog(@"...  FAILED to add sound.  There we no audio tracks in the asset");
		[NSException raise:@"Asset had no audio" format:@"line %d: File '%@.mp3' had no audio tracks", 0 /*mElement.line*/, mFilename];
	}
	
	// make an audio mix for this track (actually an AVAudioMixInputParameters
	//AVMutableAudioMixInputParameters *audioMix = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:sourceAudioTrack];
	//[audioMix setVolumeRampFromStartVolume:0.0 toEndVolume:1.0 timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(5.0, 44100))];
	// - (void)setVolumeRampFromStartVolume:(float)startVolume toEndVolume:(float)endVolume timeRange:(CMTimeRange)timeRange;
	//[theAudioMixParameters addObject:audioMix];
	
	
	NSError *err = nil;
	
	// parent span as a timerange
	//CMTimeRange parentDuration = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(mParent.durationOfMediaAndFixedPadding, 44100));
	
	[mLoopLogic begin];
	
	// the time to fill
	//CMTime endingWritePos = CMTimeMakeWithSeconds(mParent.optionalFixedDuration, 44100);
	//		CMTime desiredTotalDuration = CMTimeMakeWithSeconds(mParent.durationOfMediaAndFixedPadding, 44100);
	//		CMTimeRange rangeToFill = CMTimeRangeMake(initialWritePos, desiredTotalDuration);
	
	CMTime markIn = CMTimeMakeWithSeconds(mMarkIn, 44100);
	CMTime markOut = CMTimeMakeWithSeconds(mMarkOut, 44100);
	
	
	// if we're fitting to the end, the first time we usually start well past the markin
	double markInOutTimeRangeDurationInSeconds = mMarkOut - mMarkIn;
	double initialOffsetFromMarkIn = [mLoopLogic computeStartOffsetForFitToEnd:markInOutTimeRangeDurationInSeconds];			
	CMTime markInToUse = CMTimeAdd(markIn, CMTimeMakeWithSeconds(initialOffsetFromMarkIn,44100 ) );
	
	
	// loop as long as the next write pos is less than the final pos
	while([mLoopLogic more])
	{
		CMTime insertionPos = CMTimeMakeWithSeconds(mParent.nextWritePos, 44100);
		CMTime markOutToUse = markOut;
		
		// apply at the audio ramp for this clip

		AVMutableAudioMixInputParameters *audioEnvelope = [builder audioEnvelopeForTrack:compositionTrack];
		//AVMutableAudioMixInputParameters *audioEnvelope = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionTrack];
		[audioEnvelope setVolume:mVolume atTime:insertionPos];

		// make the timerange in the source to use
		// (when fitting-to-end, the first time in the loop we may be offset)
		CMTimeRange sourceMarkInOutTimeRange = CMTimeRangeFromTimeToTime(markInToUse, markOutToUse);
		// (any subsequent loops will use the whole markIn-markOut
		markInToUse = markIn;
		
		// TODO don't write past the end time
		// limit the source range by the amount remaining in the output!
		double moreRemaining = [mLoopLogic moreRemaining];
		if(CMTimeGetSeconds(sourceMarkInOutTimeRange.duration) > moreRemaining )
		{
			// we get here if a looping track needs to be truncated to fit a parent
			sourceMarkInOutTimeRange.duration = CMTimeMakeWithSeconds(moreRemaining, 44100);
			
			// also, fade out over the last second or so
			CMTime fadeOutBeginTime = CMTimeAdd( insertionPos, CMTimeMakeWithSeconds(moreRemaining - kFadeOutDuration, 44100) );
			CMTimeRange fadeOutRange = CMTimeRangeMake(fadeOutBeginTime, CMTimeMakeWithSeconds(kFadeOutDuration, 44100));
			[audioEnvelope setVolumeRampFromStartVolume:mVolume toEndVolume:0.0 timeRange:fadeOutRange];

			//[audioMix setVolumeRampFromStartVolume:0.0 toEndVolume:volume timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(5.0, 44100))];
		}
		
		
		// if this sound is to be used in next/prev navigation, add it now
		if(builder && mIsNavigable)
		{
			[builder addNavigationTime:mParent.nextWritePos];
			
		}
		
		BOOL success = [compositionTrack insertTimeRange:sourceMarkInOutTimeRange
												 ofTrack:sourceAudioTrack
												  atTime:insertionPos
												   error:&err];
		
		if(!success || err)
		{
			NSLog(@"...  FAILED to add sound at %f.  Error was: '%@'", mParent.nextWritePos, [err localizedDescription]);
			break; // no more writing...
		}
		else
		{
			// we succeeded!
			// update the nextwrite cursor (for left-justified siblings)
			double amountJustAdded = CMTimeGetSeconds( sourceMarkInOutTimeRange.duration);
			
			// accumulates time into parent's nextWritePos
			[mLoopLogic wroteSegment:mFilename dur:amountJustAdded];
			
			NSLog(@"...  added sound (new pos: %f)", mParent.nextWritePos);
		}
	

	}
}
+(NSURL *)findAudioFile:(NSString *)filename
{
	return [SubSegmentBuilderSound findAudioFileOfNames:[NSArray arrayWithObject:filename]];
	
}

+(NSURL *)findAudioFileOfNames:(NSArray *)filenames
{
	NSArray *extensions = [NSArray arrayWithObjects:@"aif", @"aiff", @"m4a", @"mp3", nil ] ;
	
	
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
