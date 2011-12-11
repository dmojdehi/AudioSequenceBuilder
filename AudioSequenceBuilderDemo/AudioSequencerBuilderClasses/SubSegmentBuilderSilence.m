//
//  SubSegmentBuilderSilence.m
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilderSilence.h"
#import "SubSegmentBuilderContainer.h"
#import "AudioSequenceBuilder.h"
#import "DDXMLElement.h"



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderFixedSilence
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		DDXMLNode *durationAttr = [elem attributeForName:@"duration"];
		NSString *durationStr = [durationAttr stringValue];
		if(durationStr)
		{
			// parse it from timecode (mm:ss.mmmm) to seconds
			mFixedDuration = [AudioSequenceBuilder parseTimecode:durationStr];
		}
		else
		{
			[NSException raise:@"<padding> expected a fixed duration" format:@""];
		}

#if qDurationIsReadonly
		[parent addToMediaAndFixedPadding: mFixedDuration];
#else
		parent.durationOfMediaAndFixedPadding += mFixedDuration;
#endif
		
	}
	return self;
}
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoTrack:(AVMutableCompositionTrack*)compositionTrack
{	
	mParent.nextWritePos += mFixedDuration;
}


@end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilderRelativeSilence
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		mResolvedTimeToPad = -1.0;
		
		DDXMLNode  *ratioAttr = [elem attributeForName:@"ratio"];		
		if(ratioAttr)
		{
			// it's relative, so scan upwards to find a fixed-duration parent
			//    - something above us *must* drive the duration!
			//    - Currently we only support fixed-length parents
			//		 - in the future we could support padding underneath <par>
			//	  - we also use that parent as the place we store the total ratio counter
			//
			// we will *block* on it's completion, then use *it* to derive our position info
			mRatio = [[ratioAttr stringValue] doubleValue];
		}
		else
		{
			[NSException raise:@"<padding> expected a fixed duration" format:@""];
		}
		
		// find our ancestor with a fixed duration, and accumulate our ratio into it
		mAncestorWithFixedDurationNotRetained = nil;
		SubSegmentBuilderContainer *ancestor = parent;
		while(ancestor)
		{
			if(ancestor.optionalFixedDuration != kDoesntHaveFixedDuration)
			{
				ancestor.totalOfAllocatedRatios += mRatio;
				mAncestorWithFixedDurationNotRetained = ancestor;
				break;
			}
			ancestor = ancestor.parent;
		}
		
		
	}
	return self;
}

-(void)passOneResolvePadding
{
	// we get here when the parent block is done processing 
	// (this is actually fairly early in the second pass)
	// note that any seq siblings are also dependent on us!
	// (so subsequent relative paddings will come aftwerwards
	//double amountToPad = mAncestorWithFixedDurationNotRetained.optionalFixedDuration - mAncestorWithFixedDurationNotRetained.durationOfMediaAndFixedPadding;
	double amountToPad = [mParent durationToFill];
	
	if(amountToPad > 0.0)
	{
		mResolvedTimeToPad = amountToPad * mRatio / mAncestorWithFixedDurationNotRetained.totalOfAllocatedRatios;
		NSLog(@"2nd pass: Added relative padding of %f seconds (ratio:%f of needed padding:%f, new pos = %f)", mResolvedTimeToPad, mRatio, amountToPad, mParent.nextWritePos);
	}
	else
	{
		// warn the user that, although they've specified some padding, none was needed
		NSLog(@"2nd pass: NOTE!!! Relative padding specified, but no space was available to use it!");
	}
}
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoTrack:(AVMutableCompositionTrack*)compositionTrack
{	
	mParent.nextWritePos += mResolvedTimeToPad;
}

@end


