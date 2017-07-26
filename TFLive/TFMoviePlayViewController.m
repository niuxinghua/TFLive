//
//  TFMoviePlayViewController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFMoviePlayViewController.h"
#import "TFLivePlayController.h"
#import "TFOPGLESDisplayView.h"

@interface TFMoviePlayViewController (){
    TFLivePlayController *_livePlayer;
    
    UISlider *_frameSlider;
}

@end

@implementation TFMoviePlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    NSURL *liveURL = [NSURL URLWithString:_liveAddr];
    
    _livePlayer = [[TFLivePlayController alloc] initWithLiveURL:liveURL];
    [_livePlayer prepareToPlay];
    
    //_livePlayer.playView.frame = CGRectMake(0, 100, 50, 100);
    _livePlayer.playView.frame = self.view.bounds;
    [self.view addSubview:_livePlayer.playView];
    
    _frameSlider = [[UISlider alloc] initWithFrame:CGRectMake(30, 80, [UIScreen mainScreen].bounds.size.width - 60, 20)];
    [_frameSlider addTarget:self action:@selector(adjustFrame:) forControlEvents:(UIControlEventValueChanged)];
    _frameSlider.value = 1.0;
    [self.view addSubview:_frameSlider];
}

-(void)adjustFrame:(UISlider *)slider{
    //_livePlayer.playView.transform = CGAffineTransformMakeScale(slider.value, slider.value);
    _livePlayer.playView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width * slider.value, [UIScreen mainScreen].bounds.size.height * slider.value);
}

-(void)dealloc{
    [_livePlayer stop];
}

@end
