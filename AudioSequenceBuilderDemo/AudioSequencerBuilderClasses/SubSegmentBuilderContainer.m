//
//  AudioSegmentBuilder2Container.m
//  iTwelve
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilderContainer.h"
#import "AudioSequenceBuilder.h"
#import "DDXMLElement.h"
#import <AVFoundation/AVFoundation.h>

const double kDoesntHaveFixedDuration = -1.0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderContainer
@synthesize childBuilders = mChildBuilders;
@synthesize playCount = mPlayCount;
@synthesize durationOfMediaAndFixedPadding = mDurationOfMediaAndFixedPadding;
@synthesize totalOfAllocatedRatios = mTotalOfAllocatedRatios;
@synthesize optionalFixedDuration = mOptionalFixedDuration;
@synthesize nextWritePos = mNextWritePos;
@synthesize isParallel = mIsParallel;

-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		mChildBuilders = [[NSMutableArray alloc]init];
		mNextWritePos = 0.0;
		
		NSString *nodeName = elem.name;
		mIsParallel = false;
		if (nodeName && [nodeName compare:@"par"] == 0)
			mIsParallel = true;
		
		// get the fixed duration arg, if present
		mOptionalFixedDuration = -1.0;
		DDXMLNode *durationAttr = [elem attributeForName:@"duration"];
		if(durationAttr)
		{
			NSString *durationAttrStr = [durationAttr stringValue];
			// parse it from timecode (mm:ss.mmmm) to seconds
			double fixedDuration = [AudioSequenceBuilder parseTimecode:durationAttrStr];
			// this container has a set size!  don't mess with it
			mOptionalFixedDuration = fixedDuration;
		}
		
		// get the loop count, if present
		DDXMLNode *playCountAttr = [elem attributeForName:@"playCount"];
		mPlayCount = 1;
		if(playCountAttr)
		{
			NSString *playCountStr = [playCountAttr stringValue];
			// parse it from timecode (mm:ss.mmmm) to seconds
			mPlayCount = [playCountStr intValue];
		}
		
	}
	return self;
	
}
-(void)dealloc
{
	[mChildBuilders release];
	[super dealloc];
}
-(double)nextWritePos
{
	return mNextWritePos;
}
-(void)setNextWritePos:(double)newPos
{
	// for par's, track the longest child
	if(newPos > mGreatestNextWritePos)
		mGreatestNextWritePos = newPos;
	
	// in par's, this will be reset for each child
	// (but we accumulate it anyway, since child tracks may need a current pos anyway
	// (e.g., repeating audio tracks)
	mNextWritePos = newPos;
	
}
-(double)durationOfMediaAndFixedPadding
{
	return  mDurationOfMediaAndFixedPadding;
}
-(void)setDurationOfMediaAndFixedPadding:(double)durationOfMediaAndFixedPadding
{
	// par's don't accumulate fixed padding
	if(mIsParallel)
		mDurationOfMediaAndFixedPadding = 0.0;
	else
		mDurationOfMediaAndFixedPadding = durationOfMediaAndFixedPadding;
}
-(void)passOneResolvePadding
{
	for(SubSegmentBuilder *child in mChildBuilders)
	{
		[child passOneResolvePadding];
	}
}

// handles the calculation of remaining pad amount
// 
-(double)durationToFill
{
	double remaining = 0.0;
	if(mOptionalFixedDuration != kDoesntHaveFixedDuration)
	{
		// we have a fixed duration
		// so return how much of ourselves remains
		remaining = self.optionalFixedDuration - mDurationOfMediaAndFixedPadding;
		
	}
	else if(mParent)
	{
		// check if we are embedded in a parent that has a fixed duration
		remaining = [mParent durationToFill];
		if(mParent.isParallel && !mIsParallel)
		{
			// if our parent is a par but we are a seq, we must remove any media time we have
			// (if our parent were a Seq and we were a Seq, it would already have our media time)
			// (if we were both Par's, neither of us would care)
			remaining -= mDurationOfMediaAndFixedPadding;
		}
	}
	if(remaining < 0.0)
		remaining = 0.0;
	return remaining;
}

-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoTrack:(AVMutableCompositionTrack*)compositionTrack
{	
	// at the beginning of this pass we remember our start pos
	double beginTimeInParent = 0.0;
	if(mParent)
		beginTimeInParent = mParent.nextWritePos;
	
	// rewind to our beginning.
	mNextWritePos  = beginTimeInParent;
	
	for(SubSegmentBuilder *child in mChildBuilders)
	{
		AVMutableCompositionTrack *compositionTrackToUse = compositionTrack;
		if(mIsParallel)
		{
			mNextWritePos = beginTimeInParent;
			
			// par's require a separate track for each child
			compositionTrackToUse = [builder.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
			
			//mCompositionTrack = [[mComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] retain];
			
		}
		[child passTwoApplyMedia:builder intoTrack:compositionTrackToUse];
	}
	
	// update our parent to our last write pos
	// (parent par's will clobber this, of course)
	if(mParent)
		mParent.nextWritePos = mNextWritePos;
}

@end
