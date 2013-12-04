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
#if qDurationIsReadonly
@property (nonatomic, assign) double greatestDurationOfMediaAndFixedPadding;
#endif
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
#if qDurationIsReadonly
	return self.greatestDurationOfMediaAndFixedPadding;
#else
	return self.durationOfMediaAndFixedPaddingInternal;
#endif
}

#if qDurationIsReadonly
-(void)addToMediaAndFixedPadding:(double)duration
{
	self.durationOfMediaAndFixedPaddingInternal += duration;
	if(self.durationOfMediaAndFixedPadding > self.greatestDurationOfMediaAndFixedPadding)
		self.greatestDurationOfMediaAndFixedPadding = self.durationOfMediaAndFixedPaddingInternal;
}

#else
-(void)setDurationOfMediaAndFixedPadding:(double)durationOfMediaAndFixedPadding
{
	// par's don't accumulate fixed padding
	if(self.isParallel)
		self.durationOfMediaAndFixedPadding = 0.0;
	else
		self.durationOfMediaAndFixedPadding = durationOfMediaAndFixedPadding;
}
#endif
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
	else if(mParent)
	{
		// we're not fixed, perhaps a parent is?
		hasAny = [mParent hasAnyFixedDurations];	
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
	else if(mParent)
	{
		remaining = self.greatestDurationOfMediaAndFixedPadding;
		
		if(mParent)
		{
			// check if we are embedded in a parent that has a fixed duration
			remaining = [mParent durationToFill];
		}
		
#if qDurationIsReadonly
#else
		if(mParent.isParallel && !mIsParallel)
		{
			// if our parent is a par but we are a seq, we must remove any media time we have
			// (if our parent were a Seq and we were a Seq, it would already have our media time)
			// (if we were both Par's, neither of us would care)
			remaining -= mDurationOfMediaAndFixedPadding;
		}
#endif
	}
	if(remaining < 0.0)
		remaining = 0.0;
	return remaining;
}

-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrackIgnored andVideoTrack:(AVMutableCompositionTrack*)videoTrackIgnored
{
	// at the beginning of this pass we remember our start pos
	double beginTimeInParent = 0.0;
	if(mParent)
		beginTimeInParent = mParent.nextWritePos;
	
	// rewind to our beginning.
	self.nextWritePos  = beginTimeInParent;
	// was using the internal value directly.  was this a bug or a feature?
	//self.nextWritePosInternal = beginTimeInParent;
	
	// recurse into the children
	// (par's orchestrate which track to use here)
	[self.childBuilders enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		SubSegmentBuilder *child = (SubSegmentBuilder *)obj;
		

#if 1
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
		//[child passTwoApplyMedia:builder intoTrack:compositionTrackToUse];
		
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
		
		
#else
		// set the 'par' mode on the track stack
		// (media elems will create new tracks or reuse existing ones depending on this setting!)
		builder.trackStack.isParMode = mIsParallel;
		
		//AVMutableCompositionTrack *compositionTrackToUse = builder.trackStack.currentTrack ;
		int savedAudioTrackIndex = builder.trackStack.currentAudioTrackIndex;
		int savedVideoTrackIndex = builder.trackStack.currentVideoTrackIndex;
		if(mIsParallel)
		{
			mNextWritePos = beginTimeInParent;
		}
		
		[child passTwoApplyMedia:builder];
		
		if(!mIsParallel)
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
