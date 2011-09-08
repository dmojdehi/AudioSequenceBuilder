//
//  SubSegmentBuilderSilence.h
//  iTwelve
//
//  Created by David Mojdehi on 8/3/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "SubSegmentBuilder.h"



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface SubSegmentBuilderFixedSilence : SubSegmentBuilder {
	double mFixedDuration;
	
}

@end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface SubSegmentBuilderRelativeSilence : SubSegmentBuilder {
	
    double mRatio;
	double mResolvedTimeToPad;
	SubSegmentBuilderContainer *mAncestorWithFixedDurationNotRetained;
}
@end

