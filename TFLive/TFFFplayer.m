//
//  TFFFplayer.c
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFFFplayer.h"


#pragma mark - definitions

void startReadPackets(TFVideoState *videoState);
int decodeStream(TFLivePlayer *player, int streamIndex);

void packetQueueInit(TFPacketQueue *pktQueue, char *name);
void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt);
AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished);
void packetQueueDestory(TFPacketQueue *pktQueue);

void frameQueueInit(TFFrameQueue *frameQueue, char *name);
void frameQueuePut(TFFrameDisplayer *display, TFFrameQueue *frameQueue, AVFrame *frame);
TFFrame* frameQueueGet(TFFrameQueue *frameQueue, bool *finished);
void frameQueueDestory(TFFrameQueue *frameQueue);

inline static TFFrame *TFFRameFillOrAlloc(TFFrameDisplayer *display, TFFrame *compositeFrame, AVFrame *originalFrame);

#pragma mark -

int findStreams(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    if (avformat_open_input(&formatCtx, videoState->filename, NULL, NULL) != 0) {
        printf("open stream failed");
        return -1;
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) != 0) {
        printf("find stream info failed");
        return -1;
    }
    int nb_streams = formatCtx->nb_streams;
    printf("after nb_streams: %d",nb_streams);
    
    videoState->formatCtx = formatCtx;
    
    //find stream by type
    int streamIndex[AVMEDIA_TYPE_NB];
    memset(streamIndex, -1, sizeof(streamIndex));
    
    streamIndex[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_SUBTITLE] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_SUBTITLE, -1, -1, NULL, 0);
    
    //video
    if (streamIndex[AVMEDIA_TYPE_VIDEO] >= 0) {
        decodeStream(player, streamIndex[AVMEDIA_TYPE_VIDEO]);
        
        //subtitle
        if (streamIndex[AVMEDIA_TYPE_SUBTITLE] >= 0) {
            decodeStream(player, streamIndex[AVMEDIA_TYPE_SUBTITLE]);
        }
    }
    
    //audio
    if (streamIndex[AVMEDIA_TYPE_AUDIO] >= 0) {
        decodeStream(player, streamIndex[AVMEDIA_TYPE_AUDIO]);
    }
    
    startReadPackets(videoState);
    
    return 0;
}

int decodeStream(TFLivePlayer *player, int streamIndex){
    
    TFVideoState *videoState = player->videoState;
    AVFormatContext *formatCtx = videoState->formatCtx;
    
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    int retval = avcodec_parameters_to_context(codecCtx, formatCtx->streams[streamIndex]->codecpar);
    
    if (retval) {
        printf("con't set codec parameters to codec context");
        avcodec_free_context(&codecCtx);
        return -1;
    }
    
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec ) {
        printf("No codec could be found with id %d",codecCtx->codec_id);
        avcodec_free_context(&codecCtx);
        return -1;
    }
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        printf("open codec error");
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
        videoState->videoFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->videoFrameDecoder->frameReadThread, videoFrameRead, player, "videoFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_AUDIO){
        
    }else if (codec->type == AVMEDIA_TYPE_SUBTITLE){
        
    }
    
    return 0;
}

#pragma mark - packet queue

void startReadPackets(TFVideoState *videoState){
    
    AVFormatContext *formatCtx = videoState->formatCtx;
    AVPacket pkt1, *pkt = &pkt1;
    
    while (!videoState->abortRequest) {
        
        if (!videoState->videoPktQueue.canInsert) {
            continue;
        }
        
        printf("%s",formatCtx == NULL ?"formatCtx is null\n": "read packet\n");
        printf("*************\n");
        int retval = av_read_frame(formatCtx, pkt);
        printf("read packet ended\n");
        if (retval < 0) {
            if (retval == AVERROR_EOF) {
                printf("read frame ended");
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
    
    pktQueue->initilized = true;
    
    strcpy(pktQueue->name, name);
    pktQueue->mutex = TFSDL_CreateMutex();
    pktQueue->maxAllocCount = kMaxAllocPacketNodeCount;
    pktQueue->canInsert = true;
    
    TFPacketNode *head = av_mallocz(sizeof(TFPacketNode));
    pktQueue->usedPacketNodeLast = head;
    pktQueue->recyclePacketNodeLast = head;
    
    //first init 30 nodes
    TFPacketNode *cur = head;
    for (int i = 1; i<kMaxAllocPacketNodeCount/10; i++) {
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
    printf("will put packet");
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
        
        printf("alloc new packet");
        
        if (pktQueue->allocCount >= pktQueue->maxAllocCount) {
            pktQueue->canInsert = false;
        }
    }
    
    //using recyclePacketNodeLast, and move back it if there is stil recycle node.
    pktQueue->recyclePacketNodeLast->packet = *pkt;
    pktQueue->recycleCount --;
    if (pktQueue->recycleCount != 0) {
        pktQueue->recyclePacketNodeLast = pktQueue->recyclePacketNodeLast->pre;
    }
    
    //printf("\ninsert packet: %d-%d\n",pktQueue->allocCount,pktQueue->recycleCount);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    printf("put end packet");
}

AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished){
    
    
    if (pktQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    if (pktQueue->recycleCount == pktQueue->allocCount) {
        //printf("|");
        TFSDL_UnlockMutex(pktQueue->mutex);
        return NULL;
    }
    
    AVPacket *firstPkt = &pktQueue->usedPacketNodeLast->packet;
    
    //pktQueue->usedPacketNodeLast->packet = NULL;
    pktQueue->recycleCount ++;
    
    if (pktQueue->recycleCount == 1) {
        pktQueue->recyclePacketNodeLast = pktQueue->usedPacketNodeLast;
    }
    pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->pre;
    
    if (!pktQueue->canInsert && pktQueue->recycleCount > pktQueue->allocCount/2) {
        pktQueue->canInsert = true;
    }
    
    //printf("\nmove out packet: %d-%d\n",pktQueue->allocCount,pktQueue->recycleCount);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    
    
    
    return firstPkt;
}

void packetQueueDestory(TFPacketQueue *pktQueue){
    if (pktQueue == NULL || !pktQueue->initilized) {
        return;
    }
    TFSDL_LockMutex(pktQueue->mutex);
    
    TFPacketNode *first = pktQueue->usedPacketNodeLast;
    TFPacketNode *cur = first->pre;
    while (cur != NULL) {
        
        if (cur == first) {
            av_free(cur);
            break;
        }
        
        TFPacketNode *pre = cur->pre;
        av_free(cur);
        cur = pre;
    }
    
    TFSDL_UnlockMutex(pktQueue->mutex);
}

#pragma mark - frame queue



TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx){
    TFFrameDecoder *decoder = av_mallocz(sizeof(TFFrameDecoder));
    decoder->codexCtx = codecCtx;
    
    return decoder;
}

int videoFrameRead(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    AVCodecContext *codecCtx = videoState->videoFrameDecoder->codexCtx;
    
    bool finished = false;
    AVFrame *frame = av_frame_alloc();
    int gotPicture = true;
    
    while (!finished && !videoState->abortRequest) {
        if (!videoState->videoFrameQueue.canInsert) {
            continue;
        }
        printf("will get packet ");
        AVPacket *pkt = packetQueueGet(&videoState->videoPktQueue,&finished);
        printf("get end packet\n");
        
        if (pkt == NULL) {
            continue;
        }
        
        int retval = avcodec_decode_video2(codecCtx, frame, &gotPicture, pkt);
        if (retval < 0) {
            printf("decode frame error: %d",retval);
        }

        frameQueuePut(player->dispalyer, &videoState->videoFrameQueue, frame);
    }
    
    return 0;
}

void frameQueueInit(TFFrameQueue *frameQueue, char *name){
    
    frameQueue->initilized = true;
    
    strcpy(frameQueue->name, name);
    frameQueue->mutex = TFSDL_CreateMutex();
    frameQueue->maxAllocCount = kMaxAllocFrameNodeCount;
    frameQueue->canInsert = YES;
    
    
    TFFrameNode *head = av_mallocz(sizeof(TFFrameNode));
    frameQueue->usedFrameNodeLast = head;
    frameQueue->recycleFrameNodeLast = head;
    
    //first init 30 nodes
    TFFrameNode *cur = head;
    for (int i = 1; i<kMaxAllocFrameNodeCount/10; i++) {
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        node->pre = cur;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    
    frameQueue->allocCount = 10;
    frameQueue->recycleCount = 10;
}

void frameQueuePut(TFFrameDisplayer *display, TFFrameQueue *frameQueue, AVFrame *frame){
    
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
        
        //可以超过，但是会开始限制
        if (frameQueue->allocCount >= frameQueue->maxAllocCount) {
            frameQueue->canInsert = false;
        }
        
        printf("alloc new frame");
    }
    
    
    
    //using recycleFrameNodeLast, and move back it if there is stil recycle node.
    frameQueue->recycleFrameNodeLast->frame = TFFRameFillOrAlloc(display, frameQueue->recycleFrameNodeLast->frame, frame);
    frameQueue->recycleCount --;
    if (frameQueue->recycleCount != 0) {
        frameQueue->recycleFrameNodeLast = frameQueue->recycleFrameNodeLast->pre;
    }
    
    //printf("\nframe count: %d-%d\n",frameQueue->allocCount,frameQueue->recycleCount);
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

TFFrame* frameQueueGet(TFFrameQueue *frameQueue, bool *finished){
    if (frameQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    if (frameQueue->allocCount == 0) {
        *finished = false;
        return NULL;
    }
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    if (frameQueue->recycleCount == frameQueue->allocCount) {
        //printf("=");
        TFSDL_UnlockMutex(frameQueue->mutex);
        return NULL;
    }
    
    TFFrame *firstframe = frameQueue->usedFrameNodeLast->frame;
    
    frameQueue->usedFrameNodeLast->frame = NULL;
    frameQueue->recycleCount ++;
    
    if (frameQueue->recycleCount == 1) {
        frameQueue->recycleFrameNodeLast = frameQueue->usedFrameNodeLast;
    }
    frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->pre;
    
    if (!frameQueue->canInsert && frameQueue->recycleCount > frameQueue->allocCount/2) {
        frameQueue->canInsert = true;
    }
    
    //printf("\nframe count: %d-%d\n",frameQueue->allocCount,frameQueue->recycleCount);
    
    TFSDL_UnlockMutex(frameQueue->mutex);
    
    return firstframe;
}

void frameQueueDestory(TFFrameQueue *frameQueue){
    if (frameQueue == NULL || !frameQueue->initilized) {
        return;
    }
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    TFFrameNode *first = frameQueue->usedFrameNodeLast;
    TFFrameNode *cur = first->pre;
    while (cur != NULL) {
        if (cur->frame) {
            av_frame_free(&cur->frame->frame);
            av_free(cur->frame->bitmap);
            av_free(cur->frame);
        }
        
        if (cur == first) {
            av_free(cur);
            break;
        }
        
        TFFrameNode *pre = cur->pre;
        
        av_free(cur);
        cur = pre;
    }
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

#pragma mark - display frame

inline static TFFrame *TFFRameFillOrAlloc(TFFrameDisplayer *display, TFFrame *compositeFrame, AVFrame *originalFrame){
    
    if (compositeFrame == NULL) {
        compositeFrame = av_mallocz(sizeof(TFFrame));
    }
    compositeFrame->frame = originalFrame;
    
    //overlay的create和fill因平台不同，这里做解耦处理
    if (display->createOverlay) {
        TFOverlay *bitmap = display->createOverlay();
        if (bitmap->func_fill_frame) {
            bitmap->func_fill_frame(bitmap, originalFrame);
        }
        compositeFrame->bitmap = bitmap;
    }
    
    return compositeFrame;
}

int startDisplayFrames(void *data){
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    bool finished = false;
    while (!finished) {
        TFFrame *frame = frameQueueGet(&videoState->videoFrameQueue, &finished);
        //sleep(1);
        if (frame == NULL) {
            continue;
        }
        
        
        
        if (player->dispalyer->displayOverlay) {
            player->dispalyer->displayOverlay(player->dispalyer, frame->bitmap);
        }
        
    }
    
    return 0;
}






