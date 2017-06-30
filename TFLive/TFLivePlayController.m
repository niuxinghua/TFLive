//
//  TFLivePlayController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFLivePlayController.h"
#import "TFThreadConvience.h"
#import "mem.h"
#import "avcodec.h"
#import "avformat.h"
#include "TFFFplayer.h"

@interface TFLivePlayController (){
    TFSDL_thread threadTest;
    
    TFSDL_thread readThread;
    TFSDL_thread displayThread;
    
    //stream
    TFVideoState *videsState;
}

@end

@implementation TFLivePlayController

-(instancetype)initWithLiveURL:(NSURL *)liveURL{
    if (self = [super init]) {
        self.liveURL = liveURL;
        
        [self playerInit];
    }
    
    return self;
}

int threadTestFunc(void * data){
    char *str = (char*)data;
    while (1) {
        sleep(1);
        printf("%s",str);
    }
    
    return 1;
}

-(void)playerInit{
    
    NSString *liveString = [_liveURL isFileURL] ? [_liveURL path] : [_liveURL absoluteString];
    
    //stream
    videsState = (TFVideoState *)av_mallocz(sizeof(TFVideoState));
    videsState->filename = av_strdup([liveString UTF8String]);
    strcpy(videsState->identifier, [[[NSDate date] description] UTF8String]);
    
    
    //ffmpeg global init
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
}

-(void)prepareToPlay{
    [self streamOpen];
}

-(void)stop{
    videsState->abortRequest = true;
    
    NSLog(@"abort requested");
    
    videsState->videoPktQueue.abortRequest = true;
    videsState->videoFrameQueue.abortRequest = true;
    
    pthread_cancel(readThread.thread_id);
    pthread_cancel(displayThread.thread_id);
    
    packetQueueDestory(&videsState->videoPktQueue);
    frameQueueDestory(&videsState->videoFrameQueue);
    
    if (videsState->videoFrameDecoder) {
        if (videsState->videoFrameDecoder->codexCtx) {
            avcodec_close(videsState->videoFrameDecoder->codexCtx);
        }
        av_free(videsState->videoFrameDecoder);
    }
    
    if (videsState->formatCtx) {
        NSLog(@"release formatCtx");
        avformat_close_input(&videsState->formatCtx);
    }
    
    
    //audio, subtitle ...
    
}

-(void)streamOpen{
    TFSDL_createThreadEx(&displayThread, startDisplayFrames, videsState, "displayThread");
    TFSDL_createThreadEx(&readThread, findStreams, videsState, "findStreams");
}

@end

