//
//  SubSegmentBuilder.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/2/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DDXMLElement;
@class AudioSequenceBuilder;
@class SubSegmentBuilderContainer;
@class AVMutableCompositionTrack;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface SubSegmentBuilder : NSObject
{
	DDXMLElement * mElement;
	__weak SubSegmentBuilderContainer *mParent;	
	NSString *mId;
	NSMutableSet	*mTags;
	double mBeginTimeInParent;
}
@property (nonatomic, readonly) DDXMLElement *element;
@property (nonatomic, readonly, weak) SubSegmentBuilderContainer *parent;

-(id)initWithElem:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent;
+(SubSegmentBuilder*)makeAudioSegmentBuilderFor:(DDXMLElement*)elem inContainer:(SubSegmentBuilderContainer*)parent;

-(void)passOneResolvePadding;
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoAudioTrack:(AVMutableCompositionTrack*)audioTrack andVideoTrack:(AVMutableCompositionTrack*)videoTrack;
//-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder;

@end






