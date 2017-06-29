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


typedef struct SDL_VoutOverlay_Opaque SDL_VoutOverlay_Opaque;
typedef struct SDL_VoutOverlay SDL_VoutOverlay;
typedef struct SDL_Class SDL_Class;

typedef struct TFFrameDecoder{
    TFSDL_thread frameReadThread;
    AVCodecContext *codexCtx;
    
}TFFrameDecoder;

typedef struct TFPacketNode{
    AVPacket *packet;
    struct TFPacketNode *pre;
}TFPacketNode;

typedef struct TFPacketQueue{
    //一个循环链表，一段是使用中的，一段是空闲可被重用的；使用中的最后一个next就是空闲的第一个，空闲的最后一个next就是使用中的第一个
    TFPacketNode *usedPacketNodeLast;
    TFPacketNode *recyclePacketNodeLast;
    int allocCount;
    int recycleCount;
    char name[15];
    
    TFSDL_mutex *mutex;
    
    bool abortRequest;
    
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
    char name[15];
    
    TFSDL_mutex *mutex;
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
    
}TFVideoState;




@interface TFLivePlayController (){
    TFSDL_thread threadTest;
    
    TFSDL_thread readThread;
    
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
    
    
    //ffmpeg global init
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
}

-(void)prepareToPlay{
    [self streamOpen];
}

-(void)stop{
    
}

#pragma mark - stream

-(void)streamOpen{
    
    TFSDL_createThreadEx(&readThread, findStreams, videsState, "readStream");
}

int findStreams(void *data){
    TFVideoState *videoState = data;
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    if (avformat_open_input(&formatCtx, videoState->filename, NULL, NULL) != 0) {
        NSLog(@"open stream failed");
        return -1;
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) != 0) {
        NSLog(@"find stream info failed");
        return -1;
    }
    int nb_streams = formatCtx->nb_streams;
    NSLog(@"after nb_streams: %d",nb_streams);
    
    videoState->formatCtx = formatCtx;
    
    //find stream by type
    int streamIndex[AVMEDIA_TYPE_NB];
    memset(streamIndex, -1, sizeof(streamIndex));
    
    streamIndex[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_SUBTITLE] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_SUBTITLE, -1, -1, NULL, 0);
    
    //video
    if (streamIndex[AVMEDIA_TYPE_VIDEO] != -1) {
        decodeStream(videoState, streamIndex[AVMEDIA_TYPE_VIDEO]);
        
        //subtitle
        if (streamIndex[AVMEDIA_TYPE_SUBTITLE] != -1) {
            decodeStream(videoState, streamIndex[AVMEDIA_TYPE_SUBTITLE]);
        }
    }
    
    //audio
    if (streamIndex[AVMEDIA_TYPE_AUDIO] != -1) {
        decodeStream(videoState, streamIndex[AVMEDIA_TYPE_AUDIO]);
        
        
    }
    
    return 0;
}

int decodeStream(TFVideoState *videoState, int streamIndex){
    
    AVFormatContext *formatCtx = videoState->formatCtx;
    
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    int retval = avcodec_parameters_to_context(codecCtx, formatCtx->streams[streamIndex]->codecpar);
    
    if (retval) {
        NSLog(@"con't set codec parameters to codec context");
        avcodec_free_context(&codecCtx);
        return -1;
    }
    
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec) {
        NSLog(@"No codec could be found with id %d",codecCtx->codec_id);
        avcodec_free_context(&codecCtx);
        return -1;
    }
    
    //is it not accurate？
    codecCtx->codec_id = codec->id;
    if (codec->type == AVMEDIA_TYPE_VIDEO) {
        
        videoState->videoStreamIndex = streamIndex;
        videoState->videoStream = formatCtx->streams[streamIndex];
        
        packetQueueInit(&videoState->videoPktQueue, "视频packet");
        frameQueueInit(&videoState->videoFrameQueue, "视频frame");
        
        //init decoder
        videoState->audioFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->audioFrameDecoder->frameReadThread, videoFrameRead, videoState, "videoFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_AUDIO){
        
    }else if (codec->type == AVMEDIA_TYPE_SUBTITLE){
        
    }
    
    startReadPackets(videoState);
    
    return 0;
}

#pragma mark - packet queue

void startReadPackets(TFVideoState *videoState){
    
    AVFormatContext *formatCtx = videoState->formatCtx;
    AVPacket pkt1, *pkt = &pkt1;
    
    while (!videoState->abortRequest) {
        int retval = av_read_frame(formatCtx, pkt);
        if (retval < 0) {
            if (retval == AVERROR_EOF) {
                NSLog(@"read frame ended");
            }
            
            continue;
        }
        
        if (pkt->stream_index == videoState->videoStreamIndex) {
            packetQueuePut(&videoState->videoPktQueue, pkt);
        }
        //other streams ...
    }
    
    videoState->videoPktQueue.abortRequest = true;
}

void packetQueueInit(TFPacketQueue *pktQueue, char *name){
    
    strcpy(pktQueue->name, name);
    pktQueue->mutex = TFSDL_CreateMutex();

    TFPacketNode *head = av_mallocz(sizeof(TFPacketNode));
    pktQueue->usedPacketNodeLast = head;
    pktQueue->recyclePacketNodeLast = head;
    
    //first init 10 nodes
    TFPacketNode *cur = head;
    for (int i = 1; i<10; i++) {
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        node->pre = cur;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    
    pktQueue->allocCount = 10;
    pktQueue->recycleCount = 10;
}

void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt){
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    //Alloc and insert new node if recycle node has used up.
    if (pktQueue->recycleCount == 0) {
        //recyclePacketNodeLast->pre == usedPacketNodeLast
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        pktQueue->recyclePacketNodeLast->pre = node;
        node->pre = pktQueue->usedPacketNodeLast;
        pktQueue->recyclePacketNodeLast = node;
        
        pktQueue->allocCount ++;
        pktQueue->recycleCount ++;
        
        NSLog(@"alloc new node");
    }
    
    //using recyclePacketNodeLast, and move back it if there is stil recycle node.
    pktQueue->recyclePacketNodeLast->packet = pkt;
    pktQueue->recycleCount --;
    if (pktQueue->recycleCount != 0) {
        pktQueue->recyclePacketNodeLast = pktQueue->recyclePacketNodeLast->pre;
    }
    
    TFSDL_UnlockMutex(pktQueue->mutex);
}

AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished){
    
    if (pktQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    if (pktQueue->recycleCount == pktQueue->allocCount) {
        NSLog(@"packet queue (%s) is empty now",pktQueue->name);
        return NULL;
    }
    
    AVPacket *firstPkt = pktQueue->usedPacketNodeLast->packet;
    
    pktQueue->usedPacketNodeLast->packet = NULL;
    pktQueue->recycleCount ++;
    
    if (pktQueue->recycleCount == 1) {
        pktQueue->recyclePacketNodeLast = pktQueue->usedPacketNodeLast;
    }
    pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->pre;
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    
    return firstPkt;
}

#pragma mark - frame queue

inline static TFFrame *TFFRameAlloc(AVFrame *originalFrame){
    TFFrame *compositeFrame = av_mallocz(sizeof(TFFrame));
    compositeFrame->frame = originalFrame;
    compositeFrame->bitmap = voutOverlayCreate(originalFrame);
    
    return compositeFrame;
}

inline static SDL_VoutOverlay *voutOverlayCreate(AVFrame *originalFrame){
    SDL_VoutOverlay *overlay = av_mallocz(sizeof(SDL_VoutOverlay));
    
    return overlay;
}

TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx){
    TFFrameDecoder *decoder = av_mallocz(sizeof(TFFrameDecoder));
    decoder->codexCtx = codecCtx;
    
    return decoder;
}

int videoFrameRead(void *data){
    
    TFVideoState *videoState = data;
    AVFormatContext *formatCtx = videoState->formatCtx;
    AVCodecContext *codecCtx = videoState->videoFrameDecoder->codexCtx;
    
    bool finished = false;
    AVFrame *frame = av_frame_alloc();
    int gotPicture = true;
    
    while (!finished) {
        AVPacket *pkt = packetQueueGet(&videoState->videoPktQueue,&finished);
        
        int retval = avcodec_decode_video2(codecCtx, frame, &gotPicture, pkt);
        if (retval < 0) {
            NSLog(@"decode frame error: %d",retval);
        }
        
        frameQueuePut(&videoState->videoFrameQueue, frame);
    }
    
    return 0;
}

void frameQueueInit(TFFrameQueue *frameQueue, char *name){
    
    strcpy(frameQueue->name, name);
    frameQueue->mutex = TFSDL_CreateMutex();
    
    TFFrameNode *head = av_mallocz(sizeof(TFFrameNode));
    frameQueue->usedFrameNodeLast = head;
    frameQueue->recycleFrameNodeLast = head;
    
    //first init 10 nodes
    TFFrameNode *cur = head;
    for (int i = 1; i<10; i++) {
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        node->pre = cur;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    
    frameQueue->allocCount = 10;
    frameQueue->recycleCount = 10;
}

void frameQueuePut(TFFrameQueue *frameQueue, AVFrame *frame){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    //Alloc and insert new node if recycle node has used up.
    if (frameQueue->recycleCount == 0) {
        //recycleFrameNodeLast->pre == usedFrameNodeLast
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        frameQueue->recycleFrameNodeLast->pre = node;
        node->pre = frameQueue->usedFrameNodeLast;
        frameQueue->recycleFrameNodeLast = node;
        
        frameQueue->allocCount ++;
        frameQueue->recycleCount ++;
        
        NSLog(@"alloc new node");
    }
    
    
    
    //using recycleFrameNodeLast, and move back it if there is stil recycle node.
    frameQueue->recycleFrameNodeLast->frame = TFFRameAlloc(frame);
    frameQueue->recycleCount --;
    if (frameQueue->recycleCount != 0) {
        frameQueue->recycleFrameNodeLast = frameQueue->recycleFrameNodeLast->pre;
    }
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

TFFrame* frameQueueGet(TFFrameQueue *frameQueue, bool *finished){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    if (frameQueue->recycleCount == frameQueue->allocCount) {
        NSLog(@"%s frame queue is empty now",frameQueue->name);
        return NULL;
    }
    
    TFFrame *firstframe = frameQueue->usedFrameNodeLast->frame;
    
    frameQueue->usedFrameNodeLast->frame = NULL;
    frameQueue->recycleCount ++;
    
    if (frameQueue->recycleCount == 1) {
        frameQueue->recycleFrameNodeLast = frameQueue->usedFrameNodeLast;
    }
    frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->pre;
    
    TFSDL_UnlockMutex(frameQueue->mutex);
    
    return firstframe;
}

#pragma mark - display frame

struct SDL_Class {
    const char *name;
};

struct SDL_VoutOverlay {
    int w; /**< Read-only */
    int h; /**< Read-only */
    UInt32 format; /**< Read-only */
    int planes; /**< Read-only */
    UInt16 *pitches; /**< in bytes, Read-only */
    UInt8 **pixels; /**< Read-write */
    
    int is_private;
    
    int sar_num;
    int sar_den;
    
    SDL_Class               *opaque_class;
    SDL_VoutOverlay_Opaque  *opaque;
    
    void    (*free_l)(SDL_VoutOverlay *overlay);
    int     (*lock)(SDL_VoutOverlay *overlay);
    int     (*unlock)(SDL_VoutOverlay *overlay);
    void    (*unref)(SDL_VoutOverlay *overlay);
    
    int     (*func_fill_frame)(SDL_VoutOverlay *overlay, const AVFrame *frame);
};

struct SDL_VoutOverlay_Opaque {
    TFSDL_mutex *mutex;
    
    AVFrame *managed_frame;
    AVBufferRef *frame_buffer;
    int planes;
    
    AVFrame *linked_frame;
    
    UInt16 pitches[AV_NUM_DATA_POINTERS];
    UInt8 *pixels[AV_NUM_DATA_POINTERS];
    
    int no_neon_warned;
    
    struct SwsContext *img_convert_ctx;
    int sws_flags;
};

void startDisplayFrames(TFVideoState *videoState){
    
    bool finished = false;
    while (!finished) {
        TFFrameNode *frame = frameQueueGet(&videoState->videoFrameQueue, &finished);
    }
    
}

@end
