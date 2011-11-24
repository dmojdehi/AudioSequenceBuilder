//
//  PlayerViewController.h
//  SoundSequencer
//
//  Created by David Mojdehi on 8/20/11.
//  Copyright 2011 Mindful Bear Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVAudioSession.h>

@class  AVPlayer;
@class MPVolumeView;
@class AudioSequenceBuilder;

@interface PlayerViewController : UIViewController
{
	IBOutlet UISlider *mTimeSlider;
	IBOutlet UILabel *mPassageTitle;
	
	IBOutlet UILabel *mBigTimeLabel;
	IBOutlet UILabel *mPositionLabel;
	IBOutlet UILabel *mDurationLabel;
	AVPlayer	 *mPlayer;
	AudioSequenceBuilder *mBuilder;
	IBOutlet UIView *mVolumePlaceholder;
	MPVolumeView *mVolumeView;
	IBOutlet UILabel *mTimerDebug;
	IBOutlet UIButton *mPlayPauseButton;

}

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AudioSequenceBuilder *builder;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *passageTitle;
@property (nonatomic, strong) UILabel *bigTimeLabel;
@property (nonatomic, strong) UILabel *positionLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIView *volumePlaceholder;
@property (nonatomic, strong) UILabel *timerDebug;
@property (nonatomic, strong) UIButton *playPauseButton;


- (IBAction)positionSliderValueChanged:(id)sender;
- (IBAction)positionSliderValueChangeFinished:(id)sender;

- (IBAction)playPauseButtonPressed:(id)sender;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)prevButtonPressed:(id)sender;


@end
