//
//  AudioBuilder2.h
//  AudioSequenceBuilderDemo
//
//  Created by David Mojdehi on 8/2/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVPlayer;
@class DDXMLDocument;
@class DDXMLElement;
@class AVMutableComposition;
@class AVMutableCompositionTrack;
@class AVMutableAudioMixInputParameters;
@class TrackStack;


@interface AudioSequenceBuilder : NSObject
{
	DDXMLDocument *mDocument;
	NSMutableDictionary	*mElementDictionary;
	NSMutableArray *mNavigationTimes;

	NSMutableDictionary *mAudioEnvelopesForTracks;
	TrackStack *mTrackStack;
}

@property (nonatomic, readonly) DDXMLDocument *document;
@property (nonatomic, readonly) NSArray *navigationTimes;
@property (nonatomic, readonly) TrackStack *trackStack;

-(void)loadDocument:(NSURL*)documentToLoad;
-(void)loadFromXmlString:(NSString*)xmlString;
-(AVMutableAudioMixInputParameters*)audioEnvelopeForTrack:(AVMutableCompositionTrack*)compositionTrack;


-(AVPlayer*)buildPlayer;

-(void)addNavigationTime:(double)time;

-(bool)parseDoubleAttr:(NSString*)attributeName fromElem:(DDXMLElement*)elem  result:(out double*)attrValue;
+(double)parseTimecode:(NSString*)timecode;

@end


@interface TrackStack : NSObject
@property (nonatomic, readonly, strong) AVMutableCompositionTrack* currentAudioTrack;
@property (nonatomic, readonly, strong) AVMutableCompositionTrack* currentVideoTrack;
@property (nonatomic, assign) int currentAudioTrackIndex;
@property (nonatomic, assign) int currentVideoTrackIndex;
//@property (nonatomic, assign) BOOL isParMode;
@property (nonatomic, readonly, strong) AVMutableComposition *composition;
//-(AVMutableCompositionTrack*) getOrCreateNextAudioTrack;
//-(AVMutableCompositionTrack*) getOrCreateNextVideoTrack;

@end