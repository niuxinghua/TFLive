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
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <libavutil/time.h>
//#import <Foundation/Foundation.h>
#include "TFDisplayDefinition.h"
#include "TFSyncClock.h"


#define kMaxAllocPacketNodeCount       50
#define kMaxAllocFrameNodeCount       50

#define SDL_AUDIO_MIN_BUFFER_SIZE 512

#define logBuffer(buffer,start,length,tag)     \
{   \
    printf("\n***************(0x%x)%s\n",(unsigned int)buffer,tag);      \
    uint8_t *logBuf = buffer + start;    \
    for (int i = 0; i<length; i++) {  \
        printf("%x",*logBuf);    \
        logBuf ++;   \
    }   \
    printf("\n");       \
}

typedef struct TFFrameDecoder{
    TFSDL_thread frameReadThread;
    AVCodecContext *codexCtx;
    
}TFFrameDecoder;

typedef struct TFPacketNode{
    AVPacket packet;
    struct TFPacketNode *pre;
    struct TFPacketNode *next;
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
    //TFSDL_cond *inCond;     //packet入队不加限制
    TFSDL_cond *outCond;
    
    bool abortRequest;
    
    //bool canInsert;
    
    bool initilized;
    
}TFPacketQueue;


typedef struct TFFrame{
    AVFrame *frame;
    double pts;
    double duration;
    TFOverlay *bitmap;
#if DEBUG
    uint64_t identifier;
#endif
    
}TFFrame;

typedef struct TFFrameNode{
    TFFrame *frame;
    struct TFFrameNode *pre;
    struct TFFrameNode *next;
    int index;
}TFFrameNode;

typedef TFFrame *(*TFFrameConvertFunc)(TFFrame *compositeFrame, AVFrame *originalFrame, void *data);
typedef void (*TFFrameReleaseFunc)(TFFrame **compositeFrame);
typedef struct TFFrameQueue{
    TFFrameNode *usedFrameNodeLast;
    TFFrameNode *recycleFrameNodeLast;
    int allocCount;
    int recycleCount;
    int maxAllocCount;
    char name[15];
    
    TFSDL_mutex *mutex;
    TFSDL_cond *inCond;
    TFSDL_cond *outCond;
    
    bool abortRequest;
    
    //bool canInsert;
    
    bool initilized;
    
    //用来处理AVFrame到包装数据结构TFFrame的转化，因为视频、音频帧的数据不同，但为了简便，使用共同的包装数据结构（TFFrame），所以需要在转化方法上做不同处理。
    TFFrameConvertFunc convertFunc;
    //有构建函数，就有释放函数，彻底隔离处理逻辑
    TFFrameReleaseFunc releaseFunc;
    
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
    TFPacketQueue audioPktQueue;
    
    TFFrameQueue videoFrameQueue;
    TFFrameQueue audioFrameQueue;
    
    TFFrameDecoder *videoFrameDecoder;
    TFFrameDecoder *audioFrameDecoder;
    TFFrameDecoder *subtitleFrameDecoder;
    
    AudioParams sourceAudioParams;  //当前获得的音频帧的格式信息，每解析到一个新的音频帧，这个都会变化
    AudioParams targetAudioParams;  //转化后的音频格式信息
    
    SwrContext *swrCtx;
    
    uint8_t *audioBuffer;           //最新一次读取到的音频数据
    unsigned int audioBufferSize;        //audioBuffer的大小
    unsigned int audioBufferIndex;       //audioBuffer可能被读取了一部分，然后下一次还需要接着读下去，这个变量就是用来记录上次读取位置的
    double audioPts;
    
    double frameTimer;
    double videoPts;
    
    
    //sync clock
    TFSyncClock videoClock;
    TFSyncClock audioClock;
    
    enum TFSyncClockType masterClockType;
    
    //controls
    bool abortRequest;
    
    char identifier[30];
    
    
}TFVideoState;

typedef struct TFLivePlayer{
    
    TFSDL_thread readThread;
    TFSDL_thread displayThread;
    
    TFVideoState *videoState;
    TFVideoDisplayer *videoDispalyer;
    TFAudioDisplayer *audioDisplayer;
    
}TFLivePlayer;


/***** functions *****/


int findStreams(void *data);

int startDisplayFrames(void *data);

void packetQueueDestory(TFPacketQueue *pktQueue);

void frameQueueDestory(TFFrameQueue *frameQueue);

int videoFrameRead(void *data);

int audioFrameRead(void *data);

TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx);

int fill_audio_buffer(uint8_t *buffer, int len, void *data);


//sync clock
double nextVideoTime(TFVideoState *videoState, double nextPts);


void closePlayer(TFLivePlayer *player);

#endif /* TFFFplayer_h */
