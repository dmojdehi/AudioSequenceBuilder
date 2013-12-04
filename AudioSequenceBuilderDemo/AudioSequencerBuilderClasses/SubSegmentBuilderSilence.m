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
@interface SubSegmentBuilderFixedSilence()
@property (nonatomic, assign) double fixedDuration;

@end
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
			_fixedDuration = [AudioSequenceBuilder parseTimecode:durationStr];
		}
		else
		{
			[NSException raise:@"<padding> expected a fixed duration" format:@""];
		}

		[parent addToMediaAndFixedPadding: _fixedDuration];
		
	}
	return self;
}

#if qSimplifiedStack
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder
#else
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrack andVideoTrack:(AVMutableCompositionTrack*)videoTrack
#endif
{
	self.parent.nextWritePos += self.fixedDuration;
}


@end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface SubSegmentBuilderRelativeSilence()
@property (nonatomic, assign) double ratio;
@property (nonatomic, assign) double resolvedTimeToPad;
@property (nonatomic, strong) SubSegmentBuilderContainer *ancestorWithFixedDurationNotRetained;

@end
@implementation SubSegmentBuilderRelativeSilence
-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent
{
	if((self = [super initWithElem:elem inContainer:parent]))
	{
		_resolvedTimeToPad = -1.0;
		
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
			_ratio = [[ratioAttr stringValue] doubleValue];
		}
		else
		{
			[NSException raise:@"<padding> expected a fixed duration" format:@""];
		}
		
		// find our ancestor with a fixed duration, and accumulate our ratio into it
		_ancestorWithFixedDurationNotRetained = nil;
		SubSegmentBuilderContainer *ancestor = parent;
		while(ancestor)
		{
			if(ancestor.optionalFixedDuration != kDoesntHaveFixedDuration)
			{
				ancestor.totalOfAllocatedRatios += _ratio;
				_ancestorWithFixedDurationNotRetained = ancestor;
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
	double amountToPad = [self.parent durationToFill];
	
	if(amountToPad > 0.0)
	{
		self.resolvedTimeToPad = amountToPad * self.ratio / _ancestorWithFixedDurationNotRetained.totalOfAllocatedRatios;
		NSLog(@"2nd pass: Added relative padding of %f seconds (ratio:%f of needed padding:%f, new pos = %f)", self.resolvedTimeToPad, self.ratio, amountToPad, self.parent.nextWritePos);
	}
	else
	{
		// warn the user that, although they've specified some padding, none was needed
		NSLog(@"2nd pass: NOTE!!! Relative padding specified, but no space was available to use it!");
	}
}

#if qSimplifiedStack
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder
#else
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrack andVideoTrack:(AVMutableCompositionTrack*)videoTrack
#endif
{
	self.parent.nextWritePos += self.resolvedTimeToPad;
}

@end


