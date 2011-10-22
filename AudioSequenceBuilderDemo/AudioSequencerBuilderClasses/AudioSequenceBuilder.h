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

@interface AudioSequenceBuilder : NSObject
{
	DDXMLDocument *mDocument;
	AVMutableComposition *mComposition;
	NSMutableDictionary	*mElementDictionary;
	NSMutableArray *mNavigationTimes;

	NSMutableDictionary *mAudioEnvelopesForTracks;
	NSMutableArray *mTrackPool;
}

@property (nonatomic, readonly) AVMutableComposition *composition;
@property (nonatomic, readonly) DDXMLDocument *document;
@property (nonatomic, readonly) NSArray *navigationTimes;
@property (nonatomic, readonly) NSMutableArray *trackPool;

-(void)loadDocument:(NSURL*)documentToLoad;
-(void)loadFromXmlString:(NSString*)xmlString;
-(AVMutableAudioMixInputParameters*)audioEnvelopeForTrack:(AVMutableCompositionTrack*)compositionTrack;


-(AVPlayer*)buildPlayer;

-(void)addNavigationTime:(double)time;

-(bool)parseDoubleAttr:(NSString*)attributeName fromElem:(DDXMLElement*)elem  result:(out double*)attrValue;
+(double)parseTimecode:(NSString*)timecode;

@end
