//
//  SubSegmentBuilderSound.h
//  iTwelve
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

@interface SubSegmentBuilderSound : SubSegmentBuilder {
    
	NSString *mFilename;
	NSString *mFilenameOfTrimmedMedia;
	double mMarkIn;
	double mMarkOut;
	double mVolume;
	AVURLAsset *mAsset;
	bool mIsNavigable;
	LoopLogic *mLoopLogic;
}

+(NSURL *)findAudioFile:(NSArray *)filename;

@end
