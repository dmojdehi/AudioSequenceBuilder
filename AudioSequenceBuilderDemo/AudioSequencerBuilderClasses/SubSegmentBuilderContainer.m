//
//  SubSegmentBuilderContainer.m
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilderContainer.h"
#import "AudioSequenceBuilder.h"
#import "DDXMLElement.h"
#import <AVFoundation/AVFoundation.h>

const double kDoesntHaveFixedDuration = -1.0;

@interface SubSegmentBuilderContainer()
@property (nonatomic, assign) double greatestNextWritePos;
@property (nonatomic, assign) double nextWritePosInternal;
@property (nonatomic, assign) double durationOfMediaAndFixedPaddingInternal;
@property (nonatomic, assign) double greatestDurationOfMediaAndFixedPadding;
@end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderContainer

-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		_childBuilders = [[NSMutableArray alloc]init];
		_nextWritePosInternal = 0.0;
		
		NSString *nodeName = elem.name;
		_isParallel = NO;
		if (nodeName && [nodeName compare:@"par"] == 0)
			_isParallel = YES;
		
		// get the fixed duration arg, if present
		_optionalFixedDuration = -1.0;
		DDXMLNode *durationAttr = [elem attributeForName:@"duration"];
		if(durationAttr)
		{
			NSString *durationAttrStr = [durationAttr stringValue];
			// parse it from timecode (mm:ss.mmmm) to seconds
			double fixedDuration = [AudioSequenceBuilder parseTimecode:durationAttrStr];
			// this container has a set size!  don't mess with it
			_optionalFixedDuration = fixedDuration;
		}
		
		// get the loop count, if present
		DDXMLNode *playCountAttr = [elem attributeForName:@"playCount"];
		_playCount = 1;
		if(playCountAttr)
		{
			NSString *playCountStr = [playCountAttr stringValue];
			// parse it from timecode (mm:ss.mmmm) to seconds
			_playCount = [playCountStr intValue];
		}
		
	}
	return self;
	
}
-(double)nextWritePos
{
	return self.nextWritePosInternal;
}
-(void)setNextWritePos:(double)newPos
{
	// for par's, track the longest child
	if(newPos > self.greatestNextWritePos)
		self.greatestNextWritePos = newPos;
	
	// in par's, this will be reset for each child
	// (but we accumulate it anyway, since child tracks may need a current pos anyway
	// (e.g., repeating audio tracks)
	self.nextWritePosInternal = newPos;
	
}
-(double)durationOfMediaAndFixedPadding
{
	return self.greatestDurationOfMediaAndFixedPadding;
}

-(void)addToMediaAndFixedPadding:(double)duration
{
	self.durationOfMediaAndFixedPaddingInternal += duration;
	if(self.durationOfMediaAndFixedPadding > self.greatestDurationOfMediaAndFixedPadding)
		self.greatestDurationOfMediaAndFixedPadding = self.durationOfMediaAndFixedPaddingInternal;
}

-(void)passOneResolvePadding
{
	for(SubSegmentBuilder *child in self.childBuilders)
	{
		[child passOneResolvePadding];
	}
}

-(bool)hasAnyFixedDurations
{
	bool hasAny = false;
	if(self.optionalFixedDuration != kDoesntHaveFixedDuration)
		hasAny = true;
	else if(self.parent)
	{
		// we're not fixed, perhaps a parent is?
		hasAny = [self.parent hasAnyFixedDurations];
	}
	return hasAny;
}

// handles the calculation of remaining pad amount
// 
-(double)durationToFill
{
	double remaining = 0.0;
	if(self.optionalFixedDuration != kDoesntHaveFixedDuration)
	{
		// we have a fixed duration
		// so return how much of ourselves remains
		remaining = self.optionalFixedDuration - self.durationOfMediaAndFixedPadding;
		
	}
	else if(self.parent)
	{
		remaining = self.greatestDurationOfMediaAndFixedPadding;
		
		if(self.parent)
		{
			// check if we are embedded in a parent that has a fixed duration
			remaining = [self.parent durationToFill];
		}
		
	}
	if(remaining < 0.0)
		remaining = 0.0;
	return remaining;
}

#if qSimplifiedStack
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder
#else
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrackIgnored andVideoTrack:(AVMutableCompositionTrack*)videoTrackIgnored
#endif
{
	// at the beginning of this pass we remember our start pos
	double beginTimeInParent = 0.0;
	if(self.parent)
		beginTimeInParent = self.parent.nextWritePos;
	
	// rewind to our beginning.
	self.nextWritePos  = beginTimeInParent;
	// was using the internal value directly.  was this a bug or a feature?
	//self.nextWritePosInternal = beginTimeInParent;
	
	if(!self.isParallel && self.parent.isParallel)
	{
		// we get here for a seq inside a PAR
		// we must pre-create a track for ourselves (and our children!)
		// If these tracks aren't used they'll be cleaned up at the end
		AVMutableCompositionTrack *a = [builder.trackStack getOrCreateNextAudioTrack];
		AVMutableCompositionTrack *v = [builder.trackStack getOrCreateNextVideoTrack];
	}

	
	// recurse into the children
	// (par's orchestrate which track to use here)
	[self.childBuilders enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		SubSegmentBuilder *child = (SubSegmentBuilder *)obj;
		

#if qSimplifiedStack
		// set the 'par' mode on the track stack
		// (media elems will create new tracks or reuse existing ones depending on this setting!)
		builder.trackStack.isParMode = self.isParallel;
		
		int savedAudioTrackIndex = builder.trackStack.currentAudioTrackIndex;
		int savedVideoTrackIndex = builder.trackStack.currentVideoTrackIndex;
		if(self.isParallel)
			self.nextWritePos = beginTimeInParent;

		
		[child passTwoApplyMedia:builder];
		
		
		if(!self.isParallel)
		{
			//seq's restore the track index after child processing
			builder.trackStack.currentAudioTrackIndex = savedAudioTrackIndex;
			builder.trackStack.currentVideoTrackIndex = savedVideoTrackIndex;
		}
#else
		AVMutableCompositionTrack *compositionAudioTrackToUse = builder.trackStack.currentAudioTrack;
		AVMutableCompositionTrack *compositionVideoTrackToUse = builder.trackStack.currentVideoTrack;
		//AVMutableCompositionTrack *compositionTrackToUse = builder.trackStack.currentTrack ;
		int savedVideoTrackIndex = builder.trackStack.currentVideoTrackIndex;
		int savedAudioTrackIndex = builder.trackStack.currentAudioTrackIndex;
		if(self.isParallel)
		{
			self.nextWritePos = beginTimeInParent;
			//mNextLocalWritePos = beginTimeInParent;
						
			//mCompositionTrack = [[mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] retain];
			
		}
		[child passTwoApplyMedia:builder intoAudioTrack:compositionAudioTrackToUse andVideoTrack:compositionVideoTrackToUse];
		
		if(self.isParallel)
		{
			// advance (but don't yet allocate) the track stack
			builder.trackStack.currentAudioTrackIndex += 1;
		}
		else
		{
			//seq's restore the track index after child processing
			builder.trackStack.currentAudioTrackIndex = savedAudioTrackIndex;
			builder.trackStack.currentVideoTrackIndex = savedVideoTrackIndex;
		}
		
#endif
		
	}];
	
	// update our parent to our last write pos
	// (parent par's will clobber this, of course)
	if(self.parent)
		self.parent.nextWritePos = self.nextWritePos;
}

@end
