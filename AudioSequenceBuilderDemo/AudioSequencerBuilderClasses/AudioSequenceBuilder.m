//
//  AudioBuilder2.m
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/2/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "AudioSequenceBuilder.h"
#import <AVFoundation/AVFoundation.h>
#import "DDXML.h"
#import "SubSegmentBuilder.h"

@implementation AudioSequenceBuilder
@synthesize document = mDocument;
@synthesize navigationTimes = mNavigationTimes;
#if qUseTrackStack
@synthesize trackStack = mTrackStack;
#else
@synthesize composition = mComposition;
@synthesize trackPool = mTrackPool;
#endif
- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
#if qUseTrackStack
		mTrackStack = [[TrackStack alloc]init];
#else
		mComposition = [[AVMutableComposition composition] retain];
		mTrackPool = [[NSMutableArray alloc]init];
#endif
		mElementDictionary = [[NSMutableDictionary alloc]init];
		mNavigationTimes = [[NSMutableArray alloc]init];
		mAudioEnvelopesForTracks = [[NSMutableDictionary alloc]init];
//		mCompositionTrack = [[mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] retain];
    }
    
    return self;
}

-(void)dealloc
{
#if qUseTrackStack
	[mTrackStack release];
#else
	[mComposition release];
	[mTrackPool release];
#endif
	[mElementDictionary release];
	[mNavigationTimes release];
	[mAudioEnvelopesForTracks release];
//	[mCompositionTrack release];
	[super dealloc];
}

-(void)loadFromXmlString:(NSString*)xmlString
{	
	NSError *err = nil;
	mDocument = [[DDXMLDocument alloc] initWithXMLString:xmlString options:0 error:&err ];
}

-(void)loadDocument:(NSURL*)documentToLoad
{
	
	NSData *docData = [NSData dataWithContentsOfURL:  documentToLoad];
	
	NSError *err = nil;
	mDocument = [[DDXMLDocument alloc] initWithData:docData options:0 error:&err];
	
}

-(AVMutableAudioMixInputParameters*)audioEnvelopeForTrack:(AVMutableCompositionTrack*)compositionTrack
{
	int trackId = compositionTrack.trackID;
	AVMutableAudioMixInputParameters *envelope = [mAudioEnvelopesForTracks objectForKey:[NSNumber numberWithInt:trackId]];
	if(!envelope)
	{
		// make a new audio envelope for this track
		envelope = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionTrack];
		// remember it
		[mAudioEnvelopesForTracks setObject:envelope forKey:[NSNumber numberWithInt:trackId]];
	}
	return envelope;
}

-(AVPlayer*)buildPlayer
{
	AVPlayer *audioPlayer = nil;
	// now make something more complicated
	
	// recursively descend through all the elements in DOC
	DDXMLElement *elem = mDocument.rootElement;
	
	// recurses through the tree, building the segments below it
	SubSegmentBuilder *segBuilder = [SubSegmentBuilder makeAudioSegmentBuilderFor:elem inContainer:nil];

	// walk down the tree, applying the passes
	[segBuilder passOneResolvePadding];
	
	// final pass: write the media out!
#if qUseTrackStack
	[segBuilder passTwoApplyMedia:self intoTrack:nil ];
#else
	AVMutableCompositionTrack *compositionTrack = [mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
	[segBuilder passTwoApplyMedia:self intoTrack:compositionTrack ];
#endif
	
	// get the audio envelopes, and apply them all
	AVMutableAudioMix *theAudioMix = [AVMutableAudioMix audioMix];
	NSArray *audioMixParameters = [mAudioEnvelopesForTracks allValues];
	theAudioMix.inputParameters = audioMixParameters;	
	
	
	// make an immutable snapshot of a mutable composition for playback or inspection
#if qUseTrackStack
	AVComposition *playerItemForSnapshottedComposition = [[mTrackStack.composition copy] autorelease];
#else
	AVComposition *playerItemForSnapshottedComposition = [[mComposition copy] autorelease];
#endif
	AVPlayerItem *playerItem = [[[AVPlayerItem alloc] initWithAsset:playerItemForSnapshottedComposition] autorelease];
	playerItem.audioMix = theAudioMix;
	audioPlayer = [AVPlayer playerWithPlayerItem:playerItem];
	
	// add navigation points for the beginning & end
	double endPos = CMTimeGetSeconds(playerItem.duration);
	[self addNavigationTime:0.0];
	[self addNavigationTime:endPos ]; 
	
	// sort the navigation times
	[mNavigationTimes sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSNumber *num1 = (NSNumber*)obj1;
		NSNumber *num2 = (NSNumber*)obj2;
		if([num1 doubleValue] < [num2 doubleValue])
			return  NSOrderedAscending;
		else if([num1 doubleValue] == [num2 doubleValue])
			return  NSOrderedSame;
		else
			return NSOrderedDescending;
	} ];
	
	return audioPlayer;
}

-(bool)parseDoubleAttr:(NSString*)attributeName fromElem:(DDXMLElement*)elem  result:(out double*)attrValue
{
	bool foundAttr = false;
	if(attrValue)
		*attrValue = 0.0;
	
	// find the attribute
	DDXMLNode *attr = [elem attributeForName:attributeName];
	if(!attr)
		return false;
	
	NSString *attrStr = [attr stringValue];
	if([attrStr rangeOfString:@","].length > 0)
	{
		// the arg has a comma in it!
		// so we enter loop-count mode (needed for TTA)
		
		// first, look to see if we've already parsed this element
		
		NSValue *elemAsValue= [NSValue valueWithNonretainedObject:elem];
		NSMutableArray *parsedArrayInReverseOrder = [mElementDictionary objectForKey:elemAsValue];
		if(!parsedArrayInReverseOrder)
		{
			// not already parsed?
			// then parse the comma-separated list, and save it back for later
			parsedArrayInReverseOrder = [[[NSMutableArray alloc]init ]autorelease];
			NSArray *arrayOfFields = [attrStr componentsSeparatedByString:@","];
			for(NSString *field in arrayOfFields)
			{
				// get this field value, and store it in our list-of-args
				double fieldValue = [AudioSequenceBuilder parseTimecode: field];
				[parsedArrayInReverseOrder insertObject:[NSNumber numberWithDouble:fieldValue] atIndex:0 ];
			}
			// save the list of 'em back
			[mElementDictionary setObject:parsedArrayInReverseOrder forKey:elemAsValue];
			
		}
		
		// now take the next double (at the end of the reverse-ordered list), and return it's value
		if([parsedArrayInReverseOrder count] > 0)
		{
			NSNumber *firstArgNumber = [parsedArrayInReverseOrder lastObject];
			
			// remove the duration, but not if its the last one!
			if([parsedArrayInReverseOrder count] > 1)
				[parsedArrayInReverseOrder removeLastObject];
			
			if(attrValue)
				*attrValue = [firstArgNumber doubleValue];
			foundAttr = true;
		}
		else
		{
			// we get here if we've run out of preset values!
			NSLog(@"<%@ %@=',,,' had multiple values in a loop, but ran out!",[elem name], attributeName);
			foundAttr = false;
		}
		
		
	}
	else
	{
		// parse the float (or timecode) value
		if(attrValue)
			*attrValue = [AudioSequenceBuilder parseTimecode: attrStr];
	}
	
	return foundAttr;
	
}

-(void)addNavigationTime:(double)time
{
	[mNavigationTimes addObject:[NSNumber numberWithDouble:time]];
}


+(double)parseTimecode:(NSString*)timecode
{
	double timeToReturn = 0.0;
	
	if(timecode == nil)
	{
		
	}
	else 
	{
		// remove all commas!
		timecode = [timecode stringByReplacingOccurrencesOfString:@"," withString:@""];
		
		if( [timecode hasPrefix:@"#"])
			//else if( [timecode rangeOfString:@":"].length == 0  && [timecode rangeOfString:@"."].length == 0)
		{
			// we ge here if it's a single integer #
			// so assume it's a fixed-sample number
			NSString *timecodeAfterPoundsign = [timecode substringFromIndex:1];
			
			int sampleNumber = [timecodeAfterPoundsign intValue];
			timeToReturn = ((double) sampleNumber) / 44100.0;
			
		}
		else
		{
			// parse out all the minutes & seconds from the string
			// example input: "5:13.409"  (5 min 13 sec 409 msec)
			NSScanner *scanner = [NSScanner scannerWithString:timecode];
			
			while(![scanner isAtEnd])
			{
				double fieldVal = 0.0;
				if([scanner scanDouble:&fieldVal])
				{
					// got a new value
					timeToReturn = timeToReturn * 60.0 + fieldVal;
					if(![scanner isAtEnd])
					{
						[scanner scanString:@":" intoString:nil];
					}
				}
				else
				{
					// we get here if it couldn't parse the value
					// so we're done!
					break;
				}
			}
		}
	}
	return timeToReturn;
	
}


@end



@implementation TrackStack
@synthesize composition = mComposition;
@synthesize currentTrackIndex = mCurrentTrackIndex;
-(id)init
{
	self=[super init];
	if(self)
	{
		mComposition = [[AVMutableComposition composition] retain];
		mCurrentTrackIndex = 0;
		mTracks =[[NSMutableArray alloc]init];
	}
	return self;
}
-(void)dealloc
{
	[mComposition release];
	[mTracks release];
	[super dealloc];
}
-(AVMutableCompositionTrack*) currentTrack
{
	// get (or make) the current track
	if(mCurrentTrackIndex >= [mTracks count])
	{
		AVMutableCompositionTrack *newtrack = [mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
		[mTracks addObject:newtrack];

	}
	
	return [mTracks objectAtIndex:mCurrentTrackIndex];
}
@end