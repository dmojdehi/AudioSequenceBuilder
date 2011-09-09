//
//  SubSegmentBuilderContainer.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilder.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
extern const double kDoesntHaveFixedDuration;

@interface SubSegmentBuilderContainer : SubSegmentBuilder
{
    bool mIsParallel;
	NSMutableArray *mChildBuilders;
	
	double mOptionalFixedDuration;
	double mDurationOfMediaAndFixedPadding;
	double mTotalOfAllocatedRatios;
	int mPlayCount;
	
	double mNextWritePos; // for par's this will always be zero!
	double mGreatestNextWritePos; // useful for par's, to know the largest child duration
}
@property (nonatomic, readonly) NSMutableArray *childBuilders;
@property (nonatomic, readonly) int playCount;
@property (nonatomic) double durationOfMediaAndFixedPadding;
@property (nonatomic) double totalOfAllocatedRatios;
@property (nonatomic, readonly) double optionalFixedDuration;
@property (nonatomic) double nextWritePos;
@property (nonatomic, readonly) bool isParallel;

-(double)durationToFill;

@end