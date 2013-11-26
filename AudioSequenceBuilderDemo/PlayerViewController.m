//
//  PlayerViewController.m
//  SoundSequencer
//
//  Created by David Mojdehi on 8/20/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import "PlayerViewController.h"
#import "AudioSequenceBuilderDemoAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>
#import "AudioSequenceBuilder.h"
#import "DDXML.h"


char *kPlayerStatusObserverContext = "kPlayerStatusObserverContext";

@interface PlayerViewController ()
@property (nonatomic, weak) IBOutlet UISlider *timeSlider;
@property (nonatomic, weak) IBOutlet UILabel *passageTitle;
@property (nonatomic, weak) IBOutlet UILabel *bigTimeLabel;
@property (nonatomic, weak) IBOutlet UILabel *positionLabel;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIView *volumePlaceholder;
@property (nonatomic, weak) IBOutlet UILabel *timerDebug;
@property (nonatomic, weak) IBOutlet UIButton *playPauseButton;
//@property (nonatomic, weak) MPVolumeView *volumeView;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AudioSequenceBuilder *builder;
@property (nonatomic, strong ) NSObject *playerPeriodicObserverRef;

-(void)updateTimeOnLabel: (UILabel*) label duration:(NSTimeInterval) timeUntilDone;
-(void)buildPlayerAsync:(NSString *)xmlFilename;

- (IBAction)positionSliderValueChanged:(id)sender;
- (IBAction)positionSliderValueChangeFinished:(id)sender;

- (IBAction)playPauseButtonPressed:(id)sender;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)prevButtonPressed:(id)sender;
@end

@implementation PlayerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	// top line: "50 mins Mind Awareness Meditation with passage"
	NSString *topLine = @"Test player";
	// middle line: "God Had done for him..."
	NSString *middleLine = @"Main Info Line";
	// bottom line: "Repeats 1"
	NSString *bottomLine = @"Minor point";
	// create the custsom navigation bar
	if(true)
	{
		UIView *customHeaderView = [[UIView alloc]initWithFrame:CGRectMake(40, 0, 200, 40)];
		const CGFloat kRowHeight = 13.0;
		// top row
		if(true)
		{
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0*kRowHeight, 200, kRowHeight)];
			label.text = topLine;
			label.backgroundColor = [UIColor clearColor];
			label.font = [UIFont boldSystemFontOfSize:13];
			label.adjustsFontSizeToFitWidth = NO;
			label.textAlignment = UITextAlignmentCenter;
			label.textColor = [UIColor lightGrayColor];
			label.highlightedTextColor = [UIColor blackColor];
			[customHeaderView addSubview:label];
		}
		// middle row
		if(true)
		{
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 1*kRowHeight, 200, kRowHeight)];
			label.text = middleLine;
			label.backgroundColor = [UIColor clearColor];
			label.font = [UIFont boldSystemFontOfSize:13];
			label.adjustsFontSizeToFitWidth = NO;
			label.textAlignment = UITextAlignmentCenter;
			label.textColor = [UIColor whiteColor];
			label.highlightedTextColor = [UIColor blackColor];
			[customHeaderView addSubview:label];
		}
		// bottom row
		if(true)
		{
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 2*kRowHeight, 200, kRowHeight)];
			label.text = bottomLine;
			label.backgroundColor = [UIColor clearColor];
			label.font = [UIFont boldSystemFontOfSize:13];
			label.adjustsFontSizeToFitWidth = NO;
			label.textAlignment = UITextAlignmentCenter;
			label.textColor = [UIColor lightGrayColor];
			label.highlightedTextColor = [UIColor blackColor];
			[customHeaderView addSubview:label];
		}
		self.navigationItem.titleView = customHeaderView;
	}
	
	NSString *xmlFile = @"CarSequenceWithBackground";

//	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
//	hud.labelText = @"Loading...";

	// make the player
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		@try
		{
			[self buildPlayerAsync:xmlFile];

		}
		@catch (NSException *exception)
		{
			
		}
		@finally
		{
			// dismiss the progress bar
//			dispatch_async(dispatch_get_main_queue(), ^(void) {
//				[MBProgressHUD hideHUDForView:self.view animated:YES];
//			});
		}
		
	}];
	
	
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


-(void)viewWillDisappear:(BOOL)animated
{
	if(self.isBeingDismissed || self.isMovingFromParentViewController)
	{
		if(self.playerPeriodicObserverRef)
			[self.player removeTimeObserver:self.playerPeriodicObserverRef];
		self.playerPeriodicObserverRef = nil;
		
		[self.player removeObserver:self forKeyPath:@"status" context:kPlayerStatusObserverContext];
	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (IBAction)playPauseButtonPressed:(id)sender
{
	// if we're paused, play
	if(self.player.rate == 0.0)
	{
		[self.player play];
		[self.playPauseButton setImage:[UIImage imageNamed:@"pauseEnabled.png"] forState:UIControlStateNormal];
	}
	else
	{
		[self.player pause];
		[self.playPauseButton setImage:[UIImage imageNamed:@"playEnabled.png"] forState:UIControlStateNormal];
	}
	
	// update the ui with our current state
	
}

- (IBAction)nextButtonPressed:(id)sender 
{
	double currentPos = CMTimeGetSeconds( self.player.currentTime );
	// find where we are in the navigation array, and go to the next one
	[self.builder.navigationTimes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		// 
		NSNumber *navPoint = (NSNumber *)obj;
		if([navPoint doubleValue] > currentPos)
		{
			// this is the first greater time, so we'll seek to it!
			*stop = YES;
			CMTime newPos = CMTimeMakeWithSeconds([navPoint doubleValue], 44100);
			[self.player seekToTime:newPos];
		}
	}];
}

- (IBAction)prevButtonPressed:(id)sender 
{
	double currentPos = CMTimeGetSeconds( self.player.currentTime );
	// find where we are in the navigation array, and go to the next one
	[self.builder.navigationTimes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		// 
		NSNumber *navPoint = (NSNumber *)obj;
		if([navPoint doubleValue] < (currentPos - 1.5))
		{
			// this is the first lesser time, so we'll seek to it!
			*stop = YES;
			CMTime newPos = CMTimeMakeWithSeconds([navPoint doubleValue], 44100);
			[self.player seekToTime:newPos];
		}
	}];
	
}

- (IBAction)positionSliderValueChanged:(id)sender
{
	[self updateTimeOnLabel:self.timerDebug duration:self.timeSlider.value];
	
}

- (IBAction)positionSliderValueChangeFinished:(id)sender
{
	if(self.player)
	{
		CMTime newPos = CMTimeMakeWithSeconds(self.timeSlider.value, 44100);
		[self.player seekToTime:newPos];
	}
	
}



-(void)buildPlayerAsync:(NSString *)xmlFilename
{
	
	// load the builder
	AudioSequenceBuilder *builder = [[AudioSequenceBuilder alloc] init ];
	
	// load the xml
	NSURL *docUrl = [[NSBundle mainBundle] URLForResource:xmlFilename withExtension:@"xml"];
	[builder loadDocument:docUrl];	
	
#if DEBUG
	NSError *error = nil;
	NSArray *sounds = [builder.document nodesForXPath:@"//sound" error:&error];
	
	for(DDXMLElement *sound in sounds)
	{
		// get the markin & markout
		DDXMLNode *fileAttr = [sound attributeForName:@"file"];
		DDXMLNode *markInAttr = [sound attributeForName:@"markIn"];
		DDXMLNode *markOutAttr = [sound attributeForName:@"markOut"];
		if(markInAttr && markOutAttr && fileAttr)
		{
			
			NSString *filename = [fileAttr stringValue];
			NSString *markInStr = [[[markInAttr stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""] stringByReplacingOccurrencesOfString:@"," withString:@""];
			NSString *markOutStr = [[[markOutAttr stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""] stringByReplacingOccurrencesOfString:@"," withString:@""];
			int markIn = [markInStr intValue];
			int markOut = [markOutStr intValue];
			int sampleCount = markOut - markIn;
			
			// write sox command to trim this file from the source
			// ./sox source.aif trimmed-1-25477775.aif trim 1s 25477774s
			NSLog(@"./sox %@.aif %@-%d-%d.aif trim %ds %ds", filename, filename, markIn, markOut, markIn, sampleCount);
		}
		
	}
#endif
	
	
	// build the player
	self.player = [builder buildPlayer];
	self.builder = builder;
	
	// once it's ready, begin playback
	[self.player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial context:kPlayerStatusObserverContext];
	

	__weak PlayerViewController *weakSelf = self;
	self.playerPeriodicObserverRef = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 44100) queue:nil usingBlock:^(CMTime time) {
		
		//
		double duration = CMTimeGetSeconds( weakSelf.player.currentItem.asset.duration );
		double pos =  CMTimeGetSeconds( time );
		double remaining = duration - pos;
		if(remaining < 0.0)
			remaining = 0.0;
		
		// some controls shouldn't be updated while we're dragging the position indicator
		if(weakSelf.timeSlider.state == UIControlStateNormal)
		{
			weakSelf.timeSlider.value = pos;
			weakSelf.timerDebug.text = [NSString stringWithFormat:@"%.2f", pos];
			[weakSelf updateTimeOnLabel:weakSelf.bigTimeLabel duration:remaining];
		}
		
		[weakSelf updateTimeOnLabel:weakSelf.positionLabel duration: pos];
		[weakSelf updateTimeOnLabel:weakSelf.durationLabel duration: duration];
		
		if(weakSelf.player.rate == 0.0)
			[weakSelf.playPauseButton setImage:[UIImage imageNamed:@"playEnabled.png"] forState:UIControlStateNormal];
		else
			[weakSelf.playPauseButton setImage:[UIImage imageNamed:@"pauseEnabled.png"] forState:UIControlStateNormal];
		
	}];

}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context == kPlayerStatusObserverContext)
	{
		AVPlayerStatus playerStatus = self.player.status;
		if(playerStatus == AVPlayerStatusReadyToPlay)
		{
			// make the player
			// make the new view
			// update the slider length & pos
			double duration = CMTimeGetSeconds( self.player.currentItem.asset.duration );
			self.timeSlider.maximumValue = duration;

			//  play it!
			[self.player play];
			
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

}



-(void)updateTimeOnLabel: (UILabel*) label duration:(NSTimeInterval) timeUntilDone
{
	// under 3 hours?
	if(timeUntilDone < 3 * 60 * 60)
	{
		// calculate h,m,s remaining
		int seconds, minutes, hours;
		hours = timeUntilDone / 3600;
		timeUntilDone = timeUntilDone - (hours * 3600);
		minutes = timeUntilDone / 60;
		timeUntilDone = timeUntilDone - (minutes * 60);
		seconds = timeUntilDone;
		
		// display it
		NSString *newText;
		if(hours > 0)
		{
			newText = [NSString stringWithFormat:@"%02d:%02d:%02d",
					   hours, minutes, seconds
					   ]; 
		}
		else {
			newText = [NSString stringWithFormat:@"%02d:%02d",
					   minutes, seconds
					   ]; 
		}
		
		label.text = newText; 
	}
	else
	{
		// we get here on 'forever'
		// So just show elapsed time
		label.text = @"--:--"; 
	}
}


@end
