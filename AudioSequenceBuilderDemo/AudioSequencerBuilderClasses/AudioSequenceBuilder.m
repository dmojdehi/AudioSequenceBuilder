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

@interface AudioSequenceBuilder()
@property (nonatomic, strong) NSMutableDictionary	*elementDictionary;
@property (nonatomic, strong) NSMutableDictionary	*audioEnvelopesForTracks;
@property (nonatomic, strong) NSMutableArray	*navigationTimesMutable;

@end
@implementation AudioSequenceBuilder
//@synthesize document = mDocument;
//@synthesize navigationTimes = mNavigationTimes;
//@synthesize trackStack = mTrackStack;
- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
		_trackStack = [[TrackStack alloc]init];
		_elementDictionary = [[NSMutableDictionary alloc]init];
		_navigationTimesMutable = [[NSMutableArray alloc]init];
		_audioEnvelopesForTracks = [[NSMutableDictionary alloc]init];
//		mCompositionTrack = [[mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] retain];
    }
    
    return self;
}
-(NSArray*)navigationTimes
{
	return self.navigationTimesMutable;
}


-(void)loadFromXmlString:(NSString*)xmlString
{	
	NSError *err = nil;
	_document = [[DDXMLDocument alloc] initWithXMLString:xmlString options:0 error:&err ];
}

-(void)loadDocument:(NSURL*)documentToLoad
{
	
	NSData *docData = [NSData dataWithContentsOfURL:  documentToLoad];
	
	NSError *err = nil;
	_document = [[DDXMLDocument alloc] initWithData:docData options:0 error:&err];
	
}

-(AVMutableAudioMixInputParameters*)audioEnvelopeForTrack:(AVMutableCompositionTrack*)compositionTrack
{
	int trackId = compositionTrack.trackID;
	AVMutableAudioMixInputParameters *envelope = self.audioEnvelopesForTracks[@(trackId)];
	if(!envelope)
	{
		// make a new audio envelope for this track
		envelope = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionTrack];
		// remember it
		self.audioEnvelopesForTracks[@(trackId)] = envelope;
	}
	return envelope;
}

-(AVPlayer*)buildPlayer
{
	AVPlayer *audioPlayer = nil;
	// now make something more complicated
	
	// recursively descend through all the elements in DOC
	DDXMLElement *elem = self.document.rootElement;
	
	// recurses through the tree, building the segments below it
	SubSegmentBuilder *segBuilder = [SubSegmentBuilder makeAudioSegmentBuilderFor:elem inContainer:nil];

	// walk down the tree, applying the passes
	[segBuilder passOneResolvePadding];
	
	// final pass: write the media out!
#if qSimplifiedStack
	[segBuilder passTwoApplyMedia:self];
#else
	[segBuilder passTwoApplyMedia:self intoAudioTrack:nil andVideoTrack:nil];
#endif
	
	
	
#if qSimplifiedStack
	// remove empty tracks
	// (this happens because PAR's must pre-generate tracks for each child.
	//   Could fix this by making the track stack smarter about when they create new tracks, but it's tricky
	//    <Par> <Seq>...</seq> <Seq>...</seq> </Par>  each inner seq must know to create a new track
	NSMutableArray *emptyTracks = [NSMutableArray array];
	[self.trackStack.composition.tracks enumerateObjectsUsingBlock:^(AVCompositionTrack *t, NSUInteger idx, BOOL *stop) {
		if(t.segments.count == 0)
		   [emptyTracks addObject:t];
	}];
	[emptyTracks enumerateObjectsUsingBlock:^(AVCompositionTrack *emptyTrack, NSUInteger idx, BOOL *stop) {
		[self.trackStack.composition removeTrack:emptyTrack];
	}];
#endif

	
	// get the audio envelopes, and apply them all
	AVMutableAudioMix *theAudioMix = [AVMutableAudioMix audioMix];
	NSArray *audioMixParameters = [self.audioEnvelopesForTracks allValues];
	theAudioMix.inputParameters = audioMixParameters;	
	
	// make an immutable snapshot of a mutable composition for playback or inspection
	AVComposition *playerItemForSnapshottedComposition = [self.trackStack.composition copy];
	AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:playerItemForSnapshottedComposition];
	playerItem.audioMix = theAudioMix;
	audioPlayer = [AVPlayer playerWithPlayerItem:playerItem];
	
	// add navigation points for the beginning & end
	double endPos = CMTimeGetSeconds(playerItem.duration);
	[self addNavigationTime:0.0];
	[self addNavigationTime:endPos ]; 
	
	// sort the navigation times
	[self.navigationTimesMutable sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
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
		NSMutableArray *parsedArrayInReverseOrder = self.elementDictionary[elemAsValue];
		if(!parsedArrayInReverseOrder)
		{
			// not already parsed?
			// then parse the comma-separated list, and save it back for later
			parsedArrayInReverseOrder = [[NSMutableArray alloc]init ];
			NSArray *arrayOfFields = [attrStr componentsSeparatedByString:@","];
			for(NSString *field in arrayOfFields)
			{
				// get this field value, and store it in our list-of-args
				double fieldValue = [AudioSequenceBuilder parseTimecode: field];
				[parsedArrayInReverseOrder insertObject:@(fieldValue) atIndex:0 ];
			}
			// save the list of 'em back
			self.elementDictionary[elemAsValue] = parsedArrayInReverseOrder;
			
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
	[self.navigationTimesMutable addObject:@(time)];
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



@interface TrackStack()
@property (nonatomic, strong) NSMutableArray *audioTracks;
@property (nonatomic, strong) NSMutableArray *videoTracks;
@end
@implementation TrackStack
-(id)init
{
	self=[super init];
	if(self)
	{
		_composition = [AVMutableComposition composition];
		_currentAudioTrackIndex = 0;
		_currentVideoTrackIndex = 0;
		_audioTracks = [[NSMutableArray alloc]init];
		_videoTracks = [[NSMutableArray alloc]init];
	}
	return self;
}
#if qSimplifiedStack
-(AVMutableCompositionTrack*) getOrCreateNextAudioTrack
{
	// get (or make) the current track
	if(self.currentAudioTrackIndex >= [self.audioTracks count])
	{
		AVMutableCompositionTrack *newtrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
		[self.audioTracks addObject:newtrack];

	}
	AVMutableCompositionTrack *track = [self.audioTracks objectAtIndex:self.currentAudioTrackIndex];
	if(self.isParMode)
		self.currentAudioTrackIndex++;

	return track;
}
-(AVMutableCompositionTrack*) getOrCreateNextVideoTrack
{
	// get (or make) the current track
	if(self.currentVideoTrackIndex >= [self.videoTracks count])
	{
		AVMutableCompositionTrack *newtrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
		[self.videoTracks addObject:newtrack];

	}

	AVMutableCompositionTrack *track = [self.videoTracks objectAtIndex:self.currentVideoTrackIndex];
	if(self.isParMode)
		self.currentVideoTrackIndex++;

	return track;
}


#else
-(AVMutableCompositionTrack*) currentAudioTrack
{
	// get (or make) the current track
	if(self.currentAudioTrackIndex >= self.audioTracks.count)
	{
		AVMutableCompositionTrack *newtrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
		[self.audioTracks addObject:newtrack];
		
	}
	
	return self.audioTracks[self.currentAudioTrackIndex];
}
-(AVMutableCompositionTrack*) currentVideoTrack
{
	// get (or make) the current track
	if(self.currentVideoTrackIndex >= self.videoTracks.count)
	{
		AVMutableCompositionTrack *newtrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
		[self.videoTracks addObject:newtrack];
		
	}
	
	return self.videoTracks[self.currentVideoTrackIndex];
}
#endif

@end