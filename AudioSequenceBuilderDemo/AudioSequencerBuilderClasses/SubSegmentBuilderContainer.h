//
//  SubSegmentBuilderContainer.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilder.h"

#define qDurationIsReadonly		1

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
extern const double kDoesntHaveFixedDuration;

@interface SubSegmentBuilderContainer : SubSegmentBuilder
@property (nonatomic, strong, readonly) NSMutableArray *childBuilders;
@property (nonatomic, assign, readonly) int playCount;
#if qDurationIsReadonly
@property (nonatomic, assign, readonly) double durationOfMediaAndFixedPadding;
#else
@property (nonatomic, assign) double durationOfMediaAndFixedPadding;
#endif
@property (nonatomic, assign) double totalOfAllocatedRatios;
@property (nonatomic, assign, readonly) double optionalFixedDuration;
@property (nonatomic, assign) double nextWritePos;
@property (nonatomic, assign, readonly) BOOL isParallel;

-(double)durationToFill;
-(bool)hasAnyFixedDurations;
#if qDurationIsReadonly
-(void)addToMediaAndFixedPadding:(double)duration;
#endif

@end