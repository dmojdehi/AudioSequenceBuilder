//
//  AudioSegmentBuilder2.m
//  iTwelve
//
//  Created by David Mojdehi on 8/2/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilder.h"
#import "AudioSegmentBuilder2Container.h"
#import "AudioSegmentBuilder2Sound.h"
#import "AudioSegmentBuilder2Silence.h"
#import "DDXMLElement.h"
#import "AudioSequenceBuilder.h"


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation SubSegmentBuilder

@synthesize element = mElement;
@synthesize parent = mParent;

-(id)initWithElem:(DDXMLElement*)elem inContainer:(AudioSegmentBuilder2Container*)parent
{
    self = [super init];
    if (self) {
        // Initialization code here.
		mElement = elem;
		mParent = [parent retain];
		mId = [[[elem attributeForName:@"id"] stringValue] copy];
		
		// get the tags from:
		//			tags="xyz,pdq,mnop"
		mTags = [[NSMutableSet alloc]init ];
		NSString *tags = [[elem attributeForName:@"tags"] stringValue];
		NSArray *tagsArray = [tags componentsSeparatedByString:@","];
		[tagsArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSString *objAsString = (NSString *)obj;
			NSString *withoutComma = [objAsString stringByReplacingOccurrencesOfString:@"," withString:@""];
			[mTags addObject:withoutComma];
		}];

    }
    
    return self;
}
-(void)dealloc
{
	
	[mId release];
	[mParent release];
	[mElement release];
	[mTags release];
	[super dealloc];
}

+(SubSegmentBuilder*)makeAudioSegmentBuilderFor:(DDXMLElement*)elem inContainer:(AudioSegmentBuilder2Container*)parent
{
	// makes (but not process) the builder
	SubSegmentBuilder *segBuilder = nil;
	// if it's a sequence, push a new group
	// if it's a file, append the file to the current composition
	NSString *nodeName = elem.name;
	
	if([nodeName compare:@"seq"] == 0 || 
	   [nodeName compare:@"root"] == 0 ||
	   [nodeName compare:@"par"] == 0 )
	{
		AudioSegmentBuilder2Container *segBuilderAsContainer = [[[AudioSegmentBuilder2Container alloc]initWithElem:elem inContainer:parent ]autorelease];
		segBuilder = segBuilderAsContainer;
		
		//=============================================
		// here is our 'pass zero'
		// for each playcount, recursively instantiate children elemements
		for(int playCounter = 0; playCounter < segBuilderAsContainer.playCount; playCounter++)
		{
			// descend into any children of this node
			NSArray *childrenNodes = elem.children;
			if(childrenNodes && [childrenNodes count])
			{
				for(DDXMLNode *childNode in childrenNodes)
				{
					if(childNode.kind == DDXMLElementKind)
					{
						DDXMLElement *childNodeAsElem = (DDXMLElement*)childNode;
						SubSegmentBuilder *childBuilder= [SubSegmentBuilder makeAudioSegmentBuilderFor:childNodeAsElem inContainer:segBuilderAsContainer];
						if(childBuilder)
							[segBuilderAsContainer.childBuilders addObject: childBuilder];
					}
				}
				
			}
		}
		//=============================================
		
		
		
		// the container has accumulated fixed media & durations
		// propogate it up to it's seq parent
		// (but not up to a PAR; it doesn't care about child durations)
		if(parent)
		{
			if(segBuilderAsContainer.optionalFixedDuration == kDoesntHaveFixedDuration)
			{
				// the container is variably-sized, so accumulate that size
				parent.durationOfMediaAndFixedPadding += segBuilderAsContainer.durationOfMediaAndFixedPadding;
			}
			else
			{
				// the container has a fixed size, so we accumulate that
				parent.durationOfMediaAndFixedPadding += segBuilderAsContainer.optionalFixedDuration;
			}			
		}

		
	}
	else if ([nodeName compare:@"sound"] == 0)
	{
		
		// figure out our justification, left, or right
		// for loop-to-fit or padding elements:
		// make the operation to create this asset 
		// make it dependent on the relevant parent elements
		// (either the previous sibling's position & duration, or the parents duration)
		
		segBuilder = [[[AudioSegmentBuilder2Sound alloc]initWithElem:elem inContainer:parent]autorelease];
		
	}
	else if([nodeName compare:@"padding"] == 0)
	{
		// see if it has fixed or relative padding
		DDXMLNode *durationAttr = [elem attributeForName:@"duration"];
		DDXMLNode  *ratioAttr = [elem attributeForName:@"ratio"];
		if(!durationAttr && !ratioAttr)
			[NSException raise:@"<padding> must have a duration!" format:@"line %d: Use either the 'duration' or 'ratio' attributes", elem.line];
		if(durationAttr && ratioAttr)
			[NSException raise:@"<padding> cannot have two durations!" format:@"line %d: Use either 'duration' or 'ratio', but not both", elem.line];
		
		//NSString *ratioStr = [ratioAttr stringValue];
		NSString *durationStr = [durationAttr stringValue];
		if(ratioAttr)
		{
			// it's relative, so scan upwards to find a fixed-duration parent
			//    - something above us *must* drive the duration!
			//    - Currently we only support fixed-length parents
			//		 - in the future we could support padding underneath <par>
			//	  - we also use that parent as the place we store the total ratio counter
			//
			// we will *block* on it's completion, then use *it* to derive our position info
			segBuilder = [[[AudioSegmentBuilder2RelativeSilence alloc] initWithElem:elem inContainer:parent] autorelease];
		}
		else if(durationStr)
		{
			segBuilder = [[[AudioSegmentBuilder2FixedSilence alloc] initWithElem:elem inContainer:parent]autorelease];
		}
	}
	else
	{
		// any other type is ignored
		NSLog(@"AudioSegmentBuilder: ignoring unknown element %@, line %d", elem.name, elem.line);
		segBuilder = nil;
	}
	
	return segBuilder;
	
}

-(void)passOneResolvePadding
{
	
}
-(void)passTwoApplyMedia:(AudioSequenceBuilder*)builder intoTrack:(AVMutableCompositionTrack*)compositionTrack
{
}

@end





