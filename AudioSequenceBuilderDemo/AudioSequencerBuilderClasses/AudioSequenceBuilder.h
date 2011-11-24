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

#define qUseTrackStack		1

@interface AudioSequenceBuilder : NSObject
{
	DDXMLDocument *mDocument;
	NSMutableDictionary	*mElementDictionary;
	NSMutableArray *mNavigationTimes;

	NSMutableDictionary *mAudioEnvelopesForTracks;
#if qUseTrackStack
	TrackStack *mTrackStack;
#else
	AVMutableComposition *mComposition;
	NSMutableArray *mTrackPool;
#endif
}

@property (nonatomic, readonly) DDXMLDocument *document;
@property (nonatomic, readonly) NSArray *navigationTimes;
#if qUseTrackStack
@property (nonatomic, readonly) TrackStack *trackStack;
#else
@property (nonatomic, readonly) AVMutableComposition *composition;
@property (nonatomic, readonly) NSMutableArray *trackPool;
#endif

-(void)loadDocument:(NSURL*)documentToLoad;
-(void)loadFromXmlString:(NSString*)xmlString;
-(AVMutableAudioMixInputParameters*)audioEnvelopeForTrack:(AVMutableCompositionTrack*)compositionTrack;


-(AVPlayer*)buildPlayer;

-(void)addNavigationTime:(double)time;

-(bool)parseDoubleAttr:(NSString*)attributeName fromElem:(DDXMLElement*)elem  result:(out double*)attrValue;
+(double)parseTimecode:(NSString*)timecode;

@end


@interface TrackStack : NSObject {
@private
	AVMutableComposition *__unsafe_unretained mComposition;

    NSMutableArray *mTracks;
	int mCurrentTrackIndex;
}
@property (unsafe_unretained, nonatomic, readonly) AVMutableCompositionTrack* currentTrack;
@property (nonatomic, assign) int currentTrackIndex;
@property (nonatomic, readonly) AVMutableComposition *composition;
@end