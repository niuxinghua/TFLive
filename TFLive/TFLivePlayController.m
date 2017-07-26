//
//  TFLivePlayController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFLivePlayController.h"
#import "TFThreadConvience.h"
#import <libavutil/mem.h>
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#include "TFFFplayer.h"
#import <UIKit/UIKit.h>
#import "TFVideoDisplayer_ios.h"
#import "TFAudioDisplayer_ios.h"

#if TFVIDEO_DISPLAYER_IOS_OPENGLES
#import "TFOPGLESDisplayView.h"
#else
#import "TFImageDisplayView.h"
#endif

@interface TFLivePlayController (){
    
    TFLivePlayer *player;
    
#if TFVIDEO_DISPLAYER_IOS_OPENGLES
    TFOPGLESDisplayView *_playView;
#else
    TFImageDisplayView *_playView;
#endif
}

@end

@implementation TFLivePlayController

-(instancetype)initWithLiveURL:(NSURL *)liveURL{
    if (self = [super init]) {
        self.liveURL = liveURL;
        
        [self playViewInit];
        [self playerInit];
    }
    
    return self;
}

-(void)playerInit{
    
    NSString *liveString = [_liveURL isFileURL] ? [_liveURL path] : [_liveURL absoluteString];
    
    player = av_mallocz(sizeof(TFLivePlayer));
    
    //stream
    TFVideoState *videsState = (TFVideoState *)av_mallocz(sizeof(TFVideoState));
    videsState->filename = av_strdup([liveString UTF8String]);
    strcpy(videsState->identifier, [[[NSDate date] description] UTF8String]);
    
    videsState->videoClock.type = TFSyncClockTypeVideo;
    videsState->audioClock.type = TFSyncClockTypeAudio;
    
    videsState->masterClockType = TFSyncClockTypeAudio;
    
    player->videoState = videsState;
    
    player->videoDispalyer = VideoDisplayCreate((__bridge void *)(_playView));
    player->audioDisplayer = createAudioDisplayer();
    
    //ffmpeg global init
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
}

-(void)playViewInit{
#if TFVIDEO_DISPLAYER_IOS_OPENGLES
    _playView = [[TFOPGLESDisplayView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _playView.backgroundColor = [UIColor blackColor];
#else
    _playView = [[TFImageDisplayView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _playView.backgroundColor = [UIColor blackColor];
#endif
}

-(void)prepareToPlay{
    [self streamOpen];
}

-(void)stop{
    
    closePlayer(player);
    
    NSLog(@"cancel frameReadThread");
    
    
    //audio, subtitle ...
    //TODO: 建一个消息通知渠道，在解码流程所有的线程结束后，再通知释放formatContext,codecContext这些资源
}

-(void)streamOpen{
    TFSDL_createThreadEx(&player->readThread, findStreams, player, "findStreams");
}

-(void)dealloc{
    TFVideoState *videsState = player->videoState;
    
    pthread_cancel(player->readThread.thread_id);
    pthread_cancel(player->displayThread.thread_id);
    
    pthread_cancel(videsState->videoFrameDecoder->frameReadThread.thread_id);

}

@end

