//
//  SubSegmentBuilder.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/2/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioSequenceBuilder.h"

@class DDXMLElement;
@class AudioSequenceBuilder;
@class SubSegmentBuilderContainer;
@class AVMutableCompositionTrack;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface SubSegmentBuilder : NSObject
@property (nonatomic, readonly) DDXMLElement *element;
@property (nonatomic, readonly, weak) SubSegmentBuilderContainer *parent;
@property (nonatomic, readonly, strong) NSString *xmlId;
@property (nonatomic, readonly, strong) NSMutableSet *tags;

-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent;
+(SubSegmentBuilder*)makeAudioSegmentBuilderFor:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent;

-(void)passOneResolvePadding;
#if qSimplifiedStack
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder;
#else
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrack andVideoTrack:(AVMutableCompositionTrack*)videoTrack;
#endif

@end






