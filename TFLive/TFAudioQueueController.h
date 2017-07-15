//
//  TFAudioQueueController.h
//  TFLive
//
//  Created by wei shi on 2017/7/4.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TFAudioDisplayer_ios.h"

#define TFAudioQueueBufferCount     3

@interface TFAudioQueueController : NSObject

@property (nonatomic, assign) TFAudioSpecifics specifics;

-(instancetype)initWithSpecifics:(const TFAudioSpecifics*)specifics;

-(void)play;

-(void)pause;

-(void)stop;

@end
