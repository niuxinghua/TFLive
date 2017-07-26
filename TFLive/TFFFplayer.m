//
//  TFFFplayer.c
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFFFplayer.h"
#include "TFAudioQueueController.h"




#pragma mark - definitions

void startReadPackets(TFVideoState *videoState);
int decodeStream(TFLivePlayer *player, int streamIndex);

void packetQueueInit(TFPacketQueue *pktQueue, char *name);
void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt);
AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished, bool block);
void packetQueueDestory(TFPacketQueue *pktQueue);

void frameQueueInit(TFFrameQueue *frameQueue, char *name);
void frameQueuePut(TFFrameQueue *frameQueue, AVFrame *frame, void *data);
TFFrame* frameQueueGet(TFFrameQueue *frameQueue, bool *finished, bool block);
void frameQueueDestory(TFFrameQueue *frameQueue);

inline static TFFrame *TFVideoFrameFillOrAlloc(TFFrame *compositeFrame, AVFrame *originalFrame, void *data);
inline static TFFrame *TFAudioFrameConvert(TFFrame *compositeFrame, AVFrame *originalFrame, void *data);
inline static void TFFrameQueueFrameRelease(TFFrame **compositeFrameRef);

int audioOpen(TFLivePlayer *player, int64_t wanted_channel_layout, int wanted_nb_channels, int wanted_sample_rate, AudioParams *resultAudioParams);

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
    
    TFSDL_createThreadEx(&player->displayThread, startDisplayFrames, player, "displayThread");
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
    
    AVDictionary *options = NULL;
    if (codec->type == AVMEDIA_TYPE_AUDIO || codec->type == AVMEDIA_TYPE_VIDEO) {
        av_dict_set(&options, "refcounted_frames", "1", 0);
    }
    
    if (avcodec_open2(codecCtx, codec, &options) < 0) {
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
        videoState->videoFrameQueue.convertFunc = TFVideoFrameFillOrAlloc;
        //videoState->videoFrameQueue.releaseFunc = TFFrameQueueFrameRelease;
        
        //init decoder
        videoState->videoFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->videoFrameDecoder->frameReadThread, videoFrameRead, player, "videoFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_AUDIO){
        
        videoState->audioStreamIndex = streamIndex;
        videoState->audioStream = formatCtx->streams[streamIndex];
        
        packetQueueInit(&videoState->audioPktQueue, "音频packet");
        frameQueueInit(&videoState->audioFrameQueue, "音频frame");
        videoState->audioFrameQueue.convertFunc = TFAudioFrameConvert;
        //videoState->audioFrameQueue.releaseFunc = TFFrameQueueFrameRelease;
        
        //audio open
        audioOpen(player, codecCtx->channel_layout, codecCtx->channels, codecCtx->sample_rate, &videoState->targetAudioParams);
        videoState->sourceAudioParams = videoState->targetAudioParams;
        
        videoState->audioFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->audioFrameDecoder->frameReadThread, audioFrameRead, player, "audioFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_SUBTITLE){
        
    }
    
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
                //printf("read frame ended");
            }
            
            continue;
        }
        
        if (pkt->stream_index == videoState->videoStreamIndex) {
            
            if (pkt->buf == NULL) {
                printf("(pkt->buf is null\n");
                continue;
            }
            packetQueuePut(&videoState->videoPktQueue, pkt);
            
        }else if (pkt->stream_index == videoState->audioStreamIndex){
            packetQueuePut(&videoState->audioPktQueue, pkt);
        }
        
    }
    
    videoState->videoPktQueue.abortRequest = true;
}

void packetQueueInit(TFPacketQueue *pktQueue, char *name){
    
    pktQueue->initilized = true;
    
    strcpy(pktQueue->name, name);
    pktQueue->mutex = TFSDL_CreateMutex();
    pktQueue->outCond = TFSDL_CreateCond();
    pktQueue->maxAllocCount = kMaxAllocPacketNodeCount;
    
    TFPacketNode *head = av_mallocz(sizeof(TFPacketNode));
    pktQueue->usedPacketNodeLast = head;
    pktQueue->recyclePacketNodeLast = head;
    
    //first init 30 nodes
    TFPacketNode *cur = head;
    int firstInitCount = kMaxAllocPacketNodeCount/10;
    for (int i = 1; i<firstInitCount; i++) {
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        node->pre = cur;
        cur->next = node;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    cur->next = head;
    
    pktQueue->allocCount = firstInitCount;
    pktQueue->recycleCount = firstInitCount;
}

void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt){
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    //Alloc and insert new node if recycle node has used up.
    if (pktQueue->recycleCount == 0) {
        
        //recyclePacketNodeLast->pre == usedPacketNodeLast
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        
        pktQueue->recyclePacketNodeLast->next->pre = node;
        node->next = pktQueue->recyclePacketNodeLast->next;
        
        node->pre = pktQueue->usedPacketNodeLast;
        pktQueue->usedPacketNodeLast->next = node;
        
        pktQueue->recyclePacketNodeLast = node;
        
        pktQueue->allocCount ++;
        pktQueue->recycleCount ++;
    }
    
    //sorting packets by dts
    TFPacketNode *curPkt = pktQueue->recyclePacketNodeLast->next;
    TFPacketNode *insertMarkPkt = NULL;
    while (curPkt != pktQueue->usedPacketNodeLast->next ) {
        if (curPkt->packet.dts > pkt->dts) {
            curPkt = curPkt->next;
        }else{
            insertMarkPkt = curPkt;
            break;
        }
    }
    
    //first
    if (insertMarkPkt == pktQueue->recyclePacketNodeLast->next) {
        pktQueue->recyclePacketNodeLast->packet = *pkt;
        pktQueue->recycleCount --;
        pktQueue->recyclePacketNodeLast = pktQueue->recyclePacketNodeLast->pre;
    }else if (insertMarkPkt == NULL){
        //out used range
        pktQueue->usedPacketNodeLast->next->packet = *pkt;
        pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->next;
        pktQueue->recycleCount --;
    }else{
        //alloc new node and insert it to be previous of insertMarkPkt
        
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        insertMarkPkt->pre->next = node;
        node->pre = insertMarkPkt->pre;
        node->next = insertMarkPkt;
        insertMarkPkt->pre = node;
        
        node->packet = *pkt;
        
        pktQueue->allocCount ++;
    }
    TFSDL_CondSignal(pktQueue->outCond);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
}

AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished, bool block){
    
    if (pktQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    if (pktQueue->recycleCount == pktQueue->allocCount ) {
        
        if (block) {
            TFSDL_CondWait(pktQueue->outCond, pktQueue->mutex);
        }else{
            TFSDL_UnlockMutex(pktQueue->mutex);
            return NULL;
        }
    }
    
    AVPacket *firstPkt = &pktQueue->usedPacketNodeLast->packet;
    pktQueue->recycleCount ++;
    
    pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->pre;
    
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
    
    TFSDL_CondSignal(pktQueue->outCond);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    
    TFSDL_DestroyCondP(&pktQueue->outCond);
    TFSDL_DestroyMutexP(&pktQueue->mutex);
}

#pragma mark - frame queue

TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx){
    TFFrameDecoder *decoder = av_mallocz(sizeof(TFFrameDecoder));
    decoder->codexCtx = codecCtx;
    
    return decoder;
}

//视频:读取packet到frame
int videoFrameRead(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    AVCodecContext *codecCtx = videoState->videoFrameDecoder->codexCtx;
    
    bool finished = false;
    AVFrame *frame = av_frame_alloc();
    AVPacket pkt;
    
    while (!finished && !videoState->abortRequest) {
        
        int gotFrame = 0;
        while (!gotFrame && !finished) {
            
            AVPacket *pktP = packetQueueGet(&videoState->videoPktQueue,&finished, YES);
            
            if (pktP == NULL || pktP->buf == NULL) {
                continue;
            }
            //copy packet because packet in queue is recycle.
            pkt = *pktP;
            
            int retval = avcodec_decode_video2(codecCtx, frame, &gotFrame, &pkt);
            av_packet_unref(&pkt);
        }
        
        frameQueuePut(&videoState->videoFrameQueue, frame, player);
        av_frame_unref(frame);
    }
    
    //TODO: 关闭播放需要更合理处理
    if (videoState->abortRequest) {
        if (videoState->videoFrameDecoder) {
            if (videoState->videoFrameDecoder->codexCtx) {
                avcodec_close(videoState->videoFrameDecoder->codexCtx);
            }
            av_free(videoState->videoFrameDecoder);
        }
        
        if (videoState->formatCtx) {
            NSLog(@"release formatCtx");
            avformat_close_input(&videoState->formatCtx);
        }
        
        packetQueueDestory(&videoState->videoPktQueue);
        frameQueueDestory(&videoState->videoFrameQueue);
    }
    
    return 0;
}

//音频:读取packet到frame
int audioFrameRead(void *data){
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    AVFrame *frame = av_frame_alloc();
    
    //上次读取的packet,因为音频一个packet可能有多个frame，所以保留上次读取的packet，如果还有frame，继续读取这个frame
//    AVPacket *pktP = NULL;
    AVPacket pkt;
    int hasMoreFrame = true;
    
    bool finished = false;
    while (!finished && !videoState->abortRequest) {
        
        int gotFrame = false;
        
        while (!gotFrame && !finished) {
            
            //如果这一个packet已经没有更多frame读取，就换下一个frame
            if (!hasMoreFrame) {
                AVPacket *pktP = packetQueueGet(&videoState->audioPktQueue, &finished, YES);
                if (pktP == NULL) {
                    hasMoreFrame = false;
                    continue;
                }
                
                pkt = *pktP;
            }
            
            int retval = avcodec_decode_audio4(videoState->audioFrameDecoder->codexCtx, frame, &gotFrame, &pkt);
            if (retval < 0) {
                hasMoreFrame = false;
            }else{
                //读取了retval长度的数据后，把data指针后移，并且size减去相应大小，如果小于0，说明没有更多frame要读取了
                pkt.data += retval;
                pkt.size -= retval;
                if (pkt.size <= 0) {
                    hasMoreFrame = false;
                }
            }
        }
        
        frameQueuePut(&videoState->audioFrameQueue, frame, NULL);
        av_frame_unref(frame);
    }
    return 0;
}

void frameQueueInit(TFFrameQueue *frameQueue, char *name){
    
    frameQueue->initilized = true;
    
    strcpy(frameQueue->name, name);
    frameQueue->mutex = TFSDL_CreateMutex();
    frameQueue->inCond = TFSDL_CreateCond();
    frameQueue->outCond = TFSDL_CreateCond();
    frameQueue->maxAllocCount = kMaxAllocFrameNodeCount;
    //frameQueue->canInsert = YES;
    
    
    TFFrameNode *head = av_mallocz(sizeof(TFFrameNode));
    frameQueue->usedFrameNodeLast = head;
    frameQueue->recycleFrameNodeLast = head;
    head->index = 0;
    
    //first init 30 nodes
    TFFrameNode *cur = head;
    int firstInitCount = kMaxAllocFrameNodeCount/10;
    for (int i = 1; i<kMaxAllocFrameNodeCount/10; i++) {
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        node->index = i;
        node->pre = cur;
        cur->next = node;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    cur->next = head;
    
    frameQueue->allocCount = firstInitCount;
    frameQueue->recycleCount = firstInitCount;
}

void frameQueuePut(TFFrameQueue *frameQueue, AVFrame *frame, void *data){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    if (frameQueue->recycleCount == 0) {
        
        TFSDL_CondWait(frameQueue->inCond, frameQueue->mutex);
        
//        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
//        node->index = frameQueue->allocCount;
//        
//        frameQueue->recycleFrameNodeLast->next->pre = node;
//        node->next = frameQueue->recycleFrameNodeLast->next;
//        
//        node->pre = frameQueue->usedFrameNodeLast;
//        frameQueue->usedFrameNodeLast->next = node;
//        
//        frameQueue->recycleFrameNodeLast = node;
//        
//        frameQueue->allocCount ++;
//        frameQueue->recycleCount ++;
//        
//        //可以超过，但是会开始限制
//        if (frameQueue->allocCount >= frameQueue->maxAllocCount) {
//            //frameQueue->canInsert = false;
//            TFSDL_CondWait(frameQueue->inCond, frameQueue->mutex);
//        }
        
    }
    
    TFFrameNode *curFrame = frameQueue->recycleFrameNodeLast->next;
    TFFrameNode *insertMarkFrame = NULL;
    while (curFrame != frameQueue->usedFrameNodeLast->next ) {
        if (curFrame->frame->frame->pts > frame->pts) {
            curFrame = curFrame->next;
        }else{
            insertMarkFrame = curFrame;
            break;
        }
    }
    
    
    //first
    TFFrame *newFrame = frameQueue->convertFunc(frameQueue->recycleFrameNodeLast->frame, frame, data);
    if (newFrame == NULL) {
        
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    
    if (insertMarkFrame == frameQueue->recycleFrameNodeLast->next) {
        frameQueue->recycleFrameNodeLast->frame = newFrame;
        frameQueue->recycleCount --;
        frameQueue->recycleFrameNodeLast = frameQueue->recycleFrameNodeLast->pre;
        
    }else if (insertMarkFrame == NULL){
        //out used range
        frameQueue->usedFrameNodeLast->next->frame = newFrame;
        frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->next;
        frameQueue->recycleCount --;
        
    }else{
        //alloc new node and insert it to be previous of insertMarkPkt
        
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        insertMarkFrame->pre->next = node;
        node->pre = insertMarkFrame->pre;
        node->next = insertMarkFrame;
        insertMarkFrame->pre = node;
        
        node->frame = newFrame;
        
        frameQueue->allocCount ++;
    }
    
    TFSDL_CondSignal(frameQueue->outCond);
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

TFFrame *frameQueueGet(TFFrameQueue *frameQueue, bool *finished, bool block){
    
    TFSDL_LockMutex(frameQueue->mutex);
    if (frameQueue->abortRequest) {
        *finished = true;
        TFSDL_UnlockMutex(frameQueue->mutex);
        return NULL;
    }
    if (frameQueue->allocCount == 0 || frameQueue->recycleCount == frameQueue->allocCount) {
        if (block) {
            TFSDL_CondWait(frameQueue->outCond, frameQueue->mutex);
        }else{
            *finished = false;
            TFSDL_UnlockMutex(frameQueue->mutex);
            return NULL;
        }
    }
    
    TFFrame *firstFrame = frameQueue->usedFrameNodeLast->frame;
    
    TFSDL_UnlockMutex(frameQueue->mutex);
    
    return firstFrame;
}

void frameQueueUseOne(TFFrameQueue *frameQueue, bool *finished){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    if (frameQueue->abortRequest) {
        *finished = true;
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    if (frameQueue->allocCount == 0) {
        *finished = false;
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    
    if (frameQueue->recycleCount == frameQueue->allocCount) {
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    
    frameQueue->usedFrameNodeLast->frame = NULL;
    
//    if (frameQueue->releaseFunc) {
//        frameQueue->releaseFunc(&frameQueue->usedFrameNodeLast->frame);
//    }else{
//        frameQueue->usedFrameNodeLast->frame = NULL;
//    }
    
    frameQueue->recycleCount ++;
    
    frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->pre;
    
    TFSDL_CondSignal(frameQueue->inCond);
    
    TFSDL_UnlockMutex(frameQueue->mutex);
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
            av_free(cur->frame->bitmap);
            av_frame_free(&cur->frame->frame);
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

//视频frame的转换方法
inline static TFFrame *TFVideoFrameFillOrAlloc(TFFrame *compositeFrame, AVFrame *originalFrame, void *data){
    TFLivePlayer *player = data;
    TFVideoDisplayer *displayer = player->videoDispalyer;
    
    if (compositeFrame == NULL) {
        compositeFrame = av_mallocz(sizeof(TFFrame));
        compositeFrame->frame = av_frame_alloc();
    }
    //TODO: 在回收compositeFrame后，overlay又还没有显示的间隔里，可能会把overlay的内存去掉
    AVFrame *frame;
    frame = compositeFrame->frame;
    av_frame_unref(compositeFrame->frame);
    av_frame_ref(compositeFrame->frame, originalFrame);
    
    compositeFrame->pts = originalFrame->pts * av_q2d(player->videoState->videoStream->time_base);
    
    //overlay的create和fill因平台不同，这里做解耦处理
    if (displayer->createOverlay) {
        TFOverlay *bitmap = displayer->createOverlay();
        if (bitmap->fillVideoFrameFunc) {
            bitmap->fillVideoFrameFunc(bitmap, originalFrame);
        }
        compositeFrame->bitmap = bitmap;
    }
    
    
    return compositeFrame;
}

//音频frame的转换方法
inline static TFFrame *TFAudioFrameConvert(TFFrame *compositeFrame, AVFrame *originalFrame, void *data){
    
    if (compositeFrame == NULL) {
        compositeFrame = av_mallocz(sizeof(TFFrame));
        compositeFrame->frame = av_frame_alloc();
    }
    av_frame_unref(compositeFrame->frame);
    av_frame_ref(compositeFrame->frame, originalFrame);
    
#if DEBUG
    compositeFrame->identifier = av_gettime_relative();
#endif
    
    return compositeFrame;
}

inline static void TFFrameQueueFrameRelease(TFFrame **compositeFrameRef){
    if ((*compositeFrameRef)->frame) {
        av_frame_unref((*compositeFrameRef)->frame);
    }
    *compositeFrameRef = NULL;
}

#define maxFrameDuration    0.1
int startDisplayFrames(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    int64_t curPts = 0;
    
    videoState->frameTimer = av_gettime_relative() / 1000000.0;
    
    bool finished = false;
    
    while (!finished) {
        
        TFFrame *frame = frameQueueGet(&videoState->videoFrameQueue, &finished, true);
        if (frame == NULL) {
            continue;
        }
        
        double remainTime = nextVideoTime(videoState, frame->pts) - av_gettime_relative() / 1000000.0;
        
        if (frame->pts < curPts) {
            printf("find early frame\n");
        }
        curPts = frame->pts;
        
        if (remainTime > 0) {
            av_usleep(remainTime * 1000000);
            continue;
        }else if (remainTime < -maxFrameDuration){
            printf("错过frame: %.6f(%lld | %.6f)\n",remainTime,frame->frame->pts, av_gettime_relative()/1000000.0);
            frameQueueUseOne(&videoState->videoFrameQueue, &finished);
            continue;
        }
        
        frameQueueUseOne(&videoState->videoFrameQueue, &finished);
        
        if (player->videoDispalyer->displayOverlay) {
            videoState->frameTimer = av_gettime_relative() / 1000000.0;
            videoState->videoPts = frame->pts;
            player->videoDispalyer->displayOverlay(player->videoDispalyer, frame->bitmap);
        }
        av_frame_unref(frame->frame);
    
    }
    
    return 0;
}

int audioOpen(TFLivePlayer *player, int64_t wanted_channel_layout, int wanted_nb_channels, int wanted_sample_rate, AudioParams *resultAudioParams){
    
    TFAudioDisplayer *audioDisplayer = player->audioDisplayer;
    
    if (!wanted_channel_layout || wanted_nb_channels != av_get_channel_layout_nb_channels(wanted_channel_layout)) {
        wanted_channel_layout = av_get_default_channel_layout(wanted_nb_channels);
    }
    
    wanted_nb_channels = av_get_channel_layout_nb_channels(wanted_channel_layout);
    
    TFAudioSpecifics wanted_spec, spec;
    wanted_spec.channels = wanted_nb_channels;
    wanted_spec.sampleRate = wanted_sample_rate;
    
    if (wanted_spec.channels <= 0 || wanted_spec.sampleRate <= 0) {
        printf("invilid channels or sample rate!");
        return -1;
    }
    wanted_spec.format = AUDIO_S16; /**< Signed 16-bit samples */

    int bufferTimes = AUDIO_DEFAULT_BUFFER_TIMES_PER_SECOND;
    if (audioDisplayer->bufferCallbackTimesPerSecond) {
        bufferTimes = audioDisplayer->bufferCallbackTimesPerSecond(audioDisplayer);
    }
    wanted_spec.samples = 2 << av_log2(wanted_spec.sampleRate / bufferTimes);//2 << av_log2(x)是为了补全为2的倍数
    wanted_spec.fillBufferfunc = fill_audio_buffer;
    wanted_spec.callbackData = player;
    
    if (audioDisplayer->openAudio(audioDisplayer, &wanted_spec, &spec) < 0) {
        printf("can't find feasiable audio specifics\n");
        return -1;
    }
    
    resultAudioParams->freq = spec.sampleRate;
    resultAudioParams->channels = spec.channels;
    resultAudioParams->channel_layout = wanted_channel_layout;
    resultAudioParams->fmt = AV_SAMPLE_FMT_S16;
    resultAudioParams->frame_size = av_samples_get_buffer_size(NULL, resultAudioParams->channels, 1, resultAudioParams->fmt, 1);
    resultAudioParams->bytes_per_sec = av_samples_get_buffer_size(NULL, resultAudioParams->channels, resultAudioParams->freq, resultAudioParams->fmt, 1);
    if (resultAudioParams->bytes_per_sec <= 0 || resultAudioParams->frame_size <= 0) {
        av_log(NULL, AV_LOG_ERROR, "av_samples_get_buffer_size failed\n");
        return -1;
    }
    
    return 0;
}


int obtainOneAudioBuffer(TFVideoState *videoState){
    
    bool finished = false;
    frameQueueUseOne(&videoState->audioFrameQueue, &finished);
    
    TFFrame *compositeFrame = NULL;
    while (compositeFrame == NULL) {
        compositeFrame = frameQueueGet(&videoState->audioFrameQueue, &finished, true);
        if (finished) {
            return -1;
        }
    }
    
    AVFrame *frame = compositeFrame->frame;
    
    int64_t dec_channel_layout =
    (frame->channel_layout && av_frame_get_channels(frame) == av_get_channel_layout_nb_channels(frame->channel_layout)) ?
    frame->channel_layout : av_get_default_channel_layout(av_frame_get_channels(frame));
    int wanted_nb_samples = frame->nb_samples;//synchronize_audio(videoState, frame->nb_samples);
    
    int bufferSize = av_samples_get_buffer_size(NULL, frame->channels, frame->nb_samples, frame->format, 1);
    
    if (dec_channel_layout != videoState->sourceAudioParams.channel_layout
        || frame->format != videoState->sourceAudioParams.fmt
        || frame->sample_rate != videoState->sourceAudioParams.freq
        || (wanted_nb_samples != frame->nb_samples && !videoState->swrCtx)) {
        
       videoState->swrCtx = swr_alloc_set_opts(NULL, videoState->targetAudioParams.channel_layout, videoState->targetAudioParams.fmt, videoState->targetAudioParams.freq, frame->channel_layout, frame->format, frame->sample_rate, 0, NULL);
        
        if (swr_init(videoState->swrCtx) < 0) {
            printf("init swrContext error");
            return -1;
        }
        
        videoState->sourceAudioParams.fmt = frame->format;
        videoState->sourceAudioParams.freq = frame->sample_rate;
        videoState->sourceAudioParams.channel_layout = dec_channel_layout;
        videoState->sourceAudioParams.channels = av_get_channel_layout_nb_channels(dec_channel_layout);
    }
    
    
    
    if (videoState->swrCtx) {
        
        uint8_t **out = &videoState->audioBuffer;
        int out_count = (int)((int64_t)wanted_nb_samples * videoState->targetAudioParams.freq / frame->sample_rate + 256);
        int out_size = av_samples_get_buffer_size(NULL, videoState->targetAudioParams.channels, out_count, videoState->targetAudioParams.fmt, 0);
        
        if (wanted_nb_samples != frame->nb_samples) {
            //swr_set_compensation
        }
        
        av_fast_malloc(&videoState->audioBuffer, &videoState->audioBufferSize, out_size);
        if (!videoState->audioBuffer) {
            printf("malloc videostate buffer error\n");
            return -1;
        }
        
        int realOutCount = swr_convert(videoState->swrCtx, out, out_count, (const uint8_t**)frame->extended_data, frame->nb_samples);
        if (realOutCount < 0) {
            printf("swr_convert failed\n");
            return -1;
        }
        if (realOutCount == out_count) {
            printf("audio buffer maybe too small\n");
            return -1;
        }
        
        int bytesPerSample = av_get_bytes_per_sample(videoState->targetAudioParams.fmt);
        bufferSize = realOutCount * videoState->targetAudioParams.channels * bytesPerSample;
        
    }else{
        videoState->audioBuffer = frame->extended_data[0];
        
    }
    videoState->audioPts = frame->pts * av_q2d(videoState->audioStream->time_base);
    
    return bufferSize;
}

int fill_audio_buffer(uint8_t *buffer, int len, void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    TFAudioDisplayer *audioDisplayer = player->audioDisplayer;
    
    if (videoState->abortRequest) {
        return -1;
    }
    
    
    double playDelay = (double)(audioDisplayer->unplayerBufferSize + (videoState->audioBufferSize - videoState->audioBufferIndex)) / videoState->targetAudioParams.bytes_per_sec;
    
    while (len > 0) {
        if (videoState->audioBufferIndex >= videoState->audioBufferSize) {
            int bufferSize = obtainOneAudioBuffer(videoState);
            if (bufferSize <= 0) {
                videoState->audioBuffer = NULL;
                videoState->audioBufferSize = SDL_AUDIO_MIN_BUFFER_SIZE ;
                //  (/ videoState->targetAudioParams.frame_size * videoState->targetAudioParams.frame_size;)这一段是？
                
            }else{
                videoState->audioBufferSize = bufferSize;
                if (videoState->audioClock.ptsRealTimeDiff <= 0) {
                    printf("ptsRealTimeDiff initialize! | %.6f\n",av_gettime_relative()/1000000.0);
                }
                videoState->audioClock.ptsRealTimeDiff = av_gettime_relative()/1000000.0 + playDelay - videoState->audioPts;
            }
            videoState->audioBufferIndex = 0;
        }
        
        
        int copyLen = videoState->audioBufferSize - videoState->audioBufferIndex;
        if (copyLen > len) {
            copyLen = len;
        }
        
        if (videoState->audioBuffer) {
            memcpy(buffer, (uint8_t*)videoState->audioBuffer + videoState->audioBufferIndex, copyLen);
        }else{
            memset(buffer, 0, copyLen);
        }
        
        len -= copyLen;
        buffer += copyLen;
        videoState->audioBufferIndex += copyLen;
    }
    
    return 0;
}

#pragma mark - sync clock

double nextVideoTime(TFVideoState *videoState, double nextPts){
    
    double duration = nextPts - videoState->videoPts;
    
    if (videoState->masterClockType == TFSyncClockTypeAudio) {
        double nextTime = nextVideoTimeAdjustByClock(&videoState->audioClock, nextPts);
        if (nextTime > 0) {
            return nextTime;
        }
    }
    
    return videoState->frameTimer + duration;
}

#pragma mark - close player

void closePlayer(TFLivePlayer *player){
    TFVideoState *videsState = player->videoState;
    
    videsState->abortRequest = true;
    
    NSLog(@"abort requested");
    
    videsState->videoPktQueue.abortRequest = true;
    videsState->videoFrameQueue.abortRequest = true;
    
    videsState->audioPktQueue.abortRequest = true;
    videsState->audioFrameQueue.abortRequest = true;
    
    player->audioDisplayer->closeAudio(player->audioDisplayer);
    
}


