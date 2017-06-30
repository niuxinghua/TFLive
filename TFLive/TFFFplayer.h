//
//  TFFFplayer.h
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFFFplayer_h
#define TFFFplayer_h

#include <stdio.h>
#include "TFThreadConvience.h"
#include "avcodec.h"
#include "avformat.h"
#import <Foundation/Foundation.h>

#define kMaxAllocPacketNodeCount       50
#define kMaxAllocFrameNodeCount       50

typedef struct SDL_VoutOverlay_Opaque SDL_VoutOverlay_Opaque;
typedef struct SDL_VoutOverlay SDL_VoutOverlay;
typedef struct SDL_Class SDL_Class;

typedef struct TFFrameDecoder{
    TFSDL_thread frameReadThread;
    AVCodecContext *codexCtx;
    
}TFFrameDecoder;

typedef struct TFPacketNode{
    AVPacket packet;
    struct TFPacketNode *pre;
}TFPacketNode;

typedef struct TFPacketQueue{
    //一个循环链表，一段是使用中的，一段是空闲可被重用的；使用中的最后一个next就是空闲的第一个，空闲的最后一个next就是使用中的第一个
    TFPacketNode *usedPacketNodeLast;
    TFPacketNode *recyclePacketNodeLast;
    int allocCount;
    int recycleCount;
    int maxAllocCount;
    char name[15];
    
    TFSDL_mutex *mutex;
    
    bool abortRequest;
    
    bool canInsert;
    
    bool initilized;
    
}TFPacketQueue;

typedef struct TFFrame{
    AVFrame *frame;
    SDL_VoutOverlay *bitmap;
}TFFrame;

typedef struct TFFrameNode{
    TFFrame *frame;
    struct TFFrameNode *pre;
}TFFrameNode;

typedef struct TFFrameQueue{
    TFFrameNode *usedFrameNodeLast;
    TFFrameNode *recycleFrameNodeLast;
    int allocCount;
    int recycleCount;
    int maxAllocCount;
    char name[15];
    
    TFSDL_mutex *mutex;
    
    bool abortRequest;
    
    bool canInsert;
    
    bool initilized;
    
}TFFrameQueue;

typedef struct TFVideoState{
    char *filename;
    
    AVFormatContext *formatCtx;
    
    int videoStreamIndex;
    AVStream *videoStream;
    int audioStreamIndex;
    AVStream *audioStream;
    int subtitleStreamIndex;
    AVStream *subtitleStream;
    
    TFPacketQueue videoPktQueue;
    
    TFFrameQueue videoFrameQueue;
    
    TFFrameDecoder *videoFrameDecoder;
    TFFrameDecoder *audioFrameDecoder;
    TFFrameDecoder *subtitleFrameDecoder;
    
    //controls
    bool abortRequest;
    
    char identifier[30];
    
}TFVideoState;


/***** functions *****/


int findStreams(void *data);

int startDisplayFrames(void *data);

void packetQueueDestory(TFPacketQueue *pktQueue);

void frameQueueDestory(TFFrameQueue *frameQueue);

int videoFrameRead(void *data);

TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx);

inline static SDL_VoutOverlay *voutOverlayCreate(AVFrame *originalFrame);

inline static TFFrame *TFFRameAlloc(AVFrame *originalFrame);


#endif /* TFFFplayer_h */
