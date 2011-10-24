//
//  AudioSequenceBuilderDemoTests.m
//  AudioSequenceBuilderDemoTests
//
//  Created by David Mojdehi on 9/8/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "AudioSequenceBuilderDemoTests.h"

#import "AudioSequenceBuilder.h"
#import "NSObject+BlockObservation.h"
#import <AVFoundation/AVFoundation.h>
#import "DDXMLDocument.h"

@interface NSMutableDictionary(NSMultiDictionary)
-(NSArray*)objectsForKey:(id)aKey;
- (void)addObject:(id)anObject forKey:(id)aKey;
@end

@implementation NSMutableDictionary(NSMultiDictionary)
-(NSArray*)objectsForKey:(id)aKey
{
	NSMutableArray *existingArray = [self objectForKey:aKey];
	// no existing values?  add the value array
	return existingArray;
	
}
- (void)addObject:(id)anObject forKey:(id)aKey
{
	NSMutableArray *existingArray = [self objectForKey:aKey];
	// no existing values?  add the value array
	if(!existingArray)
	{
		existingArray = [[[NSMutableArray alloc]init]autorelease];
		[self setObject:existingArray forKey:aKey];
	}
	[existingArray addObject:anObject];	
}
@end


@interface AudioSequenceBuilderDemoTests(Internal)
-(void)performTestingForXml:(NSString *)filename;
@end


@implementation AudioSequenceBuilderDemoTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

//- (void)testExample
//{
//    STFail(@"Unit tests are not implemented yet in AudioSequenceBuilderDemoTests");
//}

#define ISCLOSETO(a,b)  ((a >= b *0.99) && (a<= b*1.01)) 
-(void)testAudioSimpleLooping
{
	
#if 1
	NSArray *xmlFilesToTest = [NSArray arrayWithObjects:
							   @"testTracksComplex1",
							   nil];
#else
	NSArray *xmlFilesToTest = [NSArray arrayWithObjects:@"testSimpleLoop",
							   @"testSimpleLoopNested",
							   //@"testNestedDurations",
							   @"testNestedDurations2",
							   @"testSimpleSequence",
							   @"testTracksSimple",
							   @"testTracksComplex1",
							   nil];
#endif
	for(NSString *filename in xmlFilesToTest)
	{
		[self performTestingForXml:filename];
	}
	
	
	
}

-(void)performTestingForXml:(NSString *)filename
{
 	NSURL *docUrl = [[NSBundle mainBundle] URLForResource:filename withExtension:@"xml"];	
 	//NSURL *docUrl = [[NSBundle mainBundle] URLForResource:@"testSimpleLoop" withExtension:@"xml"];
	
	AudioSequenceBuilder *builder = [[AudioSequenceBuilder alloc] init ];
	[builder loadDocument:docUrl];
	//[builder loadFromXmlString:@"<root><seq duration=\"10:00.0\"><sound file=\"BG_Reflective_Peace\" loopToFitParent=\"simple\" /></seq></root>"];
	AVPlayer *player = [[builder buildPlayer] retain];
	
	// we expect the following
	// fish out the <tests> element
	NSError *err = nil;
	// find all children of <test> elems
	NSArray *testElems = [builder.document nodesForXPath:@"//test/*" error:&err];
	//NSArray *testElem = [builder.document nodesForXPath:@"//test" error:&err];
	
	// run the tests (but wait for the player to finish loading)
	dispatch_group_t waitGroup = dispatch_group_create();
	// manually indiate that something has started
	dispatch_group_enter(waitGroup);
	[player addObserverForKeyPath:@"status" task:^(id obj, NSDictionary *change) {
		
		AVPlayerStatus playerStatus = player.status;
		
		
		// manually indiate that work has finished
		dispatch_group_leave(waitGroup);		
		
	}];
	
	// run for awhile until the player has finished loading
	bool done = false;
	do {
		// process events for a bit
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		
		//dispatch_group_wait returns 0 when the group is done
		done = dispatch_group_wait(waitGroup, 0.01) == 0;
	} while (!done);
	dispatch_release(waitGroup);
	
	
	// now, run the tests!
	NSMutableDictionary *segmentsByName = [[[NSMutableDictionary alloc] init]autorelease];
	
	// verify it built what we expected
	AVPlayerItem *playerItem = player.currentItem;
	AVAsset *playerAsset = playerItem.asset;
	AVComposition *playerAssetAsComposition = (AVComposition*)playerAsset;
	NSArray *tracks = playerAssetAsComposition.tracks;
	int totalSegments = 0;
	for(AVCompositionTrack *track in tracks)
	{
		CMTimeRange timeRange = track.timeRange;
		NSArray *segments = track.segments;
		for(AVCompositionTrackSegment *segment in segments)
		{
			NSURL *sourceUrl = segment.sourceURL;
			CMTimeMapping timeMapping = segment.timeMapping;
			double timeSrcStart = CMTimeGetSeconds(timeMapping.source.start);
			double timeSrcDuration = CMTimeGetSeconds(timeMapping.source.duration);
			double timeTargetStart = CMTimeGetSeconds(timeMapping.target.start);
			double timeTargetDuration = CMTimeGetSeconds(timeMapping.target.duration);
			NSLog(@"Segment %@, src time:%.2f dur:%.2f, target time:%.2f, dur:%.2f", [sourceUrl absoluteString], timeSrcStart, timeSrcDuration, timeTargetStart,timeTargetDuration);
			totalSegments ++;
			
			// add the filename to the array
			NSString *path = sourceUrl.path;
			NSString *filename = [[path stringByDeletingPathExtension] lastPathComponent];
			[segmentsByName addObject:segment  forKey:filename];
		}
	}
	
	// now go through the test cases, validating each of them
	for(DDXMLElement *testCase in testElems)
	{
		if([testCase.name compare:@"totalSegments" options:NSCaseInsensitiveSearch]  == 0)
		{
			// get the amount to compare
			int expectedCount = [[[testCase attributeForName:@"count"] stringValue] intValue];
			if(expectedCount != totalSegments)
				STFail(@"Test: <totalSegments> failed.  Expected count was %d, the actual count was %d", expectedCount, totalSegments);
			
		}
		else if([testCase.name compare:@"totalTracks" options:NSCaseInsensitiveSearch]  == 0)
		{
			// get the amount to compare
			int expectedCount = [[[testCase attributeForName:@"count"] stringValue] intValue];
			if(expectedCount != [tracks count])
				STFail(@"Test: <totalTracks> failed.  Expected count was %d, the actual count was %d", expectedCount, [tracks count]);
			
		}
		else if([testCase.name compare:@"segment" options:NSCaseInsensitiveSearch]  == 0)
		{
			NSString *filename = [[testCase attributeForName:@"file"] stringValue];
			NSArray *filenameInstances = [segmentsByName objectsForKey:filename];
			
			//file="BG_Reflective_Peace" targetTime="90.96" targetDuration
			if([testCase attributeForName:@"targetTime"])
			{
				double targetTime = [AudioSequenceBuilder parseTimecode:[[testCase attributeForName:@"targetTime"] stringValue] ];
				__block bool found = false;
				// test the target time of the file (we look for *any* instance of the file with that value)
				[filenameInstances enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
					AVCompositionTrackSegment *segment = (AVCompositionTrackSegment *)obj;
					
					// if 
					CMTimeMapping timeMapping = segment.timeMapping;
					double timeSrcStart = CMTimeGetSeconds(timeMapping.source.start);
					double timeSrcDuration = CMTimeGetSeconds(timeMapping.source.duration);
					double timeTargetStart = CMTimeGetSeconds(timeMapping.target.start);
					double timeTargetDuration = CMTimeGetSeconds(timeMapping.target.duration);
					if(ISCLOSETO(timeTargetStart,targetTime))
					{
						// check this time & duration!
						if([testCase attributeForName:@"targetDuration"])
						{
							double targetDuration = [AudioSequenceBuilder parseTimecode:[[testCase attributeForName:@"targetDuration"] stringValue]];
							
							if(!ISCLOSETO(timeTargetDuration, targetDuration))
								STFail(@"Test: <segment> failed -- duration was wrong.  The duration was %.2f, but %.2f was expected. (In file %@, time %.2f) ", timeTargetDuration, targetDuration, filename, targetTime );						
						}
						
						found = true;
						*stop = YES;
					}
					
				}];
				if(!found)
				{
					STFail(@"Test: <segment> failed, line %d.  TargetTime of %.2f wasn't found. (the file %@ was found in %d places) ", 0/*testCase.line*/, targetTime, filename, [filenameInstances count]);						
				}
			}
		}
	}
	
	
	
}

@end
