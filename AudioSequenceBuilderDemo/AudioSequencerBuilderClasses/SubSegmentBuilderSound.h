//
//  SubSegmentBuilderSound.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilder.h"



@class AVURLAsset;
@class LoopLogic;


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
typedef enum
{
	kLoopNone,
	kLoopSimple,
	kLoopWholeOnly,
	kLoopFromEnd
	
} LoopToFitParent;

@interface SubSegmentBuilderSound : SubSegmentBuilder
+(NSURL *)findAudioFile:(NSString *)filename;
@end
