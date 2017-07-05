//
//  TFMoviePlayViewController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFMoviePlayViewController.h"
#import "TFLivePlayController.h"

@interface TFMoviePlayViewController (){
    TFLivePlayController *_livePlayer;
}

@end

@implementation TFMoviePlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.view.backgroundColor = [UIColor whiteColor];
    NSURL *liveURL = [NSURL URLWithString:_liveAddr];
    
    _livePlayer = [[TFLivePlayController alloc] initWithLiveURL:liveURL];
    [_livePlayer prepareToPlay];
    
    _livePlayer.playView.frame = CGRectMake(0, 100, 50, 100);
    //_livePlayer.playView.frame = self.view.bounds;
    [self.view addSubview:_livePlayer.playView];
    
}

-(void)dealloc{
    [_livePlayer stop];
}

@end
