//
//  TFLivePlayController.h
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TFLivePlayController : NSObject

-(instancetype)initWithLiveURL:(NSURL *)liveURL;

@property (nonatomic, copy) NSURL *liveURL;

@property (nonatomic, strong, readonly) UIView *playView;

-(void)stop;

-(void)prepareToPlay;

@end
